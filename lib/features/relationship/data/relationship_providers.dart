import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/backend/backend_providers.dart';
import '../../characters/data/character_repository.dart';
import '../../library/data/library_repository.dart';
import '../domain/relationship_models.dart';
import 'relationship_backend.dart';
import 'server_relationship_backend.dart';

/// The relationship backend: the server when the app is connected to one,
/// otherwise the on-device sample engine.
final relationshipBackendProvider = Provider<RelationshipBackend>((ref) {
  final api = ref.watch(backendApiProvider);
  ref.watch(backendUserIdProvider);
  return api != null
      ? ServerRelationshipBackend(api)
      : MockRelationshipBackend();
});

String _key(String characterId, String personaId) => '$characterId|$personaId';

/// A cache of relationships for the persona in use. Every change goes through
/// the backend, which owns the numbers.
class RelationshipsNotifier extends Notifier<Map<String, Relationship>> {
  @override
  Map<String, Relationship> build() {
    ref.watch(backendApiProvider);
    ref.watch(backendUserIdProvider);
    return const {};
  }

  RelationshipBackend get _backend => ref.read(relationshipBackendProvider);

  /// With a server, personas are real rows: wait for them before using an id.
  Future<String> _persona() async {
    if (ref.read(usesBackendProvider)) await ref.read(personasProvider.future);
    return ref.read(activePersonaIdProvider);
  }

  void _put(Relationship r) =>
      state = {...state, _key(r.characterId, r.personaId): r};

  /// Shows a relationship the server just sent (inside a chat reply).
  void apply(Relationship r) => _put(r);

  /// Reads the relationship with this character again (it may have changed on
  /// another device).
  Future<void> refresh(String characterId) async {
    final persona = await _persona();
    String? universe;
    for (final c in ref.read(charactersProvider).valueOrNull ?? const []) {
      if (c.id == characterId) universe = c.universeId;
    }
    _put(await _backend.load(characterId, persona, universeId: universe));
  }

  /// Loads (and creates on first use) the relationship with this character.
  Future<Relationship> ensure(String characterId) async {
    final persona = await _persona();
    final existing = state[_key(characterId, persona)];
    if (existing != null) return existing;
    String? universe;
    for (final c in ref.read(charactersProvider).valueOrNull ?? const []) {
      if (c.id == characterId) universe = c.universeId;
    }
    final r = await _backend.load(characterId, persona, universeId: universe);
    // Another caller may have loaded it meanwhile.
    return state[_key(characterId, persona)] ??
        (() {
          _put(r);
          return r;
        })();
  }

  Future<RelationshipUpdate> _apply(Future<RelationshipUpdate> f) async {
    final u = await f;
    _put(u.relationship);
    return u;
  }

  Future<Relationship> _applyR(Future<Relationship> f) async {
    final r = await f;
    _put(r);
    return r;
  }

  // ── from the chat ─────────────────────────────────────────────────────

  Future<RelationshipNote?> onUserMessage({
    required String characterId,
    required String messageId,
    required String text,
    String? conversationId,
    String chatTitle = 'Story',
  }) async {
    final r = await ensure(characterId);
    final u = await _apply(
      _backend.userMessage(
        relationshipId: r.id,
        messageId: messageId,
        text: text,
        conversationId: conversationId,
        chatTitle: chatTitle,
      ),
    );
    return u.note;
  }

  Future<RelationshipNote?> onEditedMessage({
    required String characterId,
    required String messageId,
    required String text,
    String? conversationId,
    String chatTitle = 'Story',
  }) async {
    final r = await ensure(characterId);
    final u = await _apply(
      _backend.editedMessage(
        relationshipId: r.id,
        messageId: messageId,
        text: text,
        conversationId: conversationId,
        chatTitle: chatTitle,
      ),
    );
    return u.note;
  }

  Future<RelationshipNote?> onModelProposal({
    required String characterId,
    required String messageId,
    required String kindId,
    required String evidence,
    required String reason,
    required List<String> recentMessages,
    required String characterFirst,
    String? conversationId,
    String chatTitle = 'Story',
  }) async {
    final r = await ensure(characterId);
    final u = await _apply(
      _backend.modelProposal(
        relationshipId: r.id,
        messageId: messageId,
        kindId: kindId,
        evidence: evidence,
        reason: reason,
        recentMessages: recentMessages,
        characterFirst: characterFirst,
        conversationId: conversationId,
        chatTitle: chatTitle,
      ),
    );
    return u.note;
  }

  /// You switched back to a version of a reply: count what its character
  /// proposed again (the server validates it afresh).
  Future<RelationshipNote?> recountProposal(
    String characterId,
    String messageId,
    int altIndex,
  ) async {
    final r = await ensure(characterId);
    final u = await _apply(_backend.recountProposal(r.id, messageId, altIndex));
    return u.note;
  }

  Future<void> markChatDeleted(String conversationId) async {
    for (final r in await _backend.markChatDeleted(conversationId)) {
      _put(r);
    }
    // On a server the database marks the events; reload what is open.
    if (ref.read(usesBackendProvider)) {
      for (final r in state.values.toList()) {
        try {
          _put(
            await _backend.load(
              r.characterId,
              r.personaId,
              universeId: r.universeId,
            ),
          );
        } catch (_) {}
      }
    }
  }

  // ── from the journal ──────────────────────────────────────────────────

  Future<Relationship> undo(
    String characterId,
    String eventId, {
    String? reason,
  }) async {
    final r = await ensure(characterId);
    return _applyR(_backend.undo(r.id, eventId, reason: reason));
  }

  Future<void> acceptSuggestion(String characterId, String id) async {
    final r = await ensure(characterId);
    await _applyR(_backend.acceptSuggestion(r.id, id));
  }

  Future<void> dismissSuggestion(String characterId, String id) async {
    final r = await ensure(characterId);
    await _applyR(_backend.dismissSuggestion(r.id, id));
  }

  Future<void> correct(
    String characterId,
    Values values, {
    String? reason,
  }) async {
    final r = await ensure(characterId);
    await _applyR(_backend.correct(r.id, values, reason: reason));
  }

  Future<void> setType(String characterId, RelationType type) async {
    final r = await ensure(characterId);
    await _applyR(_backend.setType(r.id, type));
  }

  Future<void> setPacing(String characterId, RelPacing pacing) async {
    final r = await ensure(characterId);
    await _applyR(_backend.setPacing(r.id, pacing));
  }

  Future<void> applyPreset(String characterId, String presetId) async {
    final r = await ensure(characterId);
    await _applyR(_backend.applyPreset(r.id, presetId));
  }

  Future<void> saveStages(
    String characterId,
    List<String> names,
    int current,
    bool lock,
  ) async {
    final r = await ensure(characterId);
    await _applyR(_backend.saveStages(r.id, names, current, lock));
  }

  Future<void> addFact(
    String characterId,
    String text, {
    bool locked = true,
  }) async {
    final r = await ensure(characterId);
    await _applyR(_backend.addFact(r.id, text, locked: locked));
  }

  Future<void> setFactLocked(
    String characterId,
    String factId,
    bool locked,
  ) async {
    final r = await ensure(characterId);
    await _applyR(_backend.setFactLocked(r.id, factId, locked));
  }

  Future<void> removeFact(String characterId, String factId) async {
    final r = await ensure(characterId);
    await _applyR(_backend.removeFact(r.id, factId));
  }
}

final relationshipsProvider =
    NotifierProvider<RelationshipsNotifier, Map<String, Relationship>>(
      RelationshipsNotifier.new,
    );

/// The relationship with one character for the persona in use. Loads on first
/// use (loading until then).
final relationshipProvider = Provider.family<AsyncValue<Relationship>, String>((
  ref,
  characterId,
) {
  final persona = ref.watch(activePersonaIdProvider);
  final cached = ref.watch(relationshipsProvider)[_key(characterId, persona)];
  if (cached != null) return AsyncData(cached);
  Future.microtask(
    () => ref
        .read(relationshipsProvider.notifier)
        .ensure(characterId)
        .then((_) {}, onError: (Object _) {}),
  );
  return const AsyncLoading();
});
