import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/backend/backend_providers.dart';
import '../../../data/mock/mock_data.dart';
import '../../../data/mock/mock_scenario.dart';
import '../../characters/domain/character.dart';
import '../../library/data/library_repository.dart';
import '../../relationship/data/relationship_providers.dart';
import '../../settings/data/app_prefs.dart';
import '../domain/chat_models.dart';
import 'supabase_conversation_repository.dart';

abstract interface class ConversationRepository {
  /// Newest first.
  Future<List<Conversation>> list();
  Future<Conversation?> byId(String id);

  /// Inserts or replaces a conversation.
  Future<void> save(Conversation conversation);
  Future<void> delete(String id);

  /// Writes anything still waiting to be saved. The server reads your messages
  /// from the database, so the chat flushes before it asks for a reply.
  Future<void> flush(String id);
}

class MockConversationRepository implements ConversationRepository {
  MockConversationRepository({
    DateTime? now,
    this.scenario = MockScenario.normal,
    this.latency = Duration.zero,
  }) : _items = scenario == MockScenario.empty
           ? []
           : MockData.conversations(now ?? DateTime.now());

  final MockScenario scenario;
  final Duration latency;
  final List<Conversation> _items;

  Future<void> _gate() async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    if (scenario == MockScenario.offline) throw const OfflineException();
  }

  @override
  Future<List<Conversation>> list() async {
    await _gate();
    final sorted = List.of(_items)
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return sorted;
  }

  @override
  Future<Conversation?> byId(String id) async {
    await _gate();
    for (final c in _items) {
      if (c.id == id) return c;
    }
    return null;
  }

  @override
  Future<void> save(Conversation conversation) async {
    final i = _items.indexWhere((c) => c.id == conversation.id);
    if (i < 0) {
      _items.add(conversation);
    } else {
      _items[i] = conversation;
    }
  }

  @override
  Future<void> delete(String id) async => _items.removeWhere((c) => c.id == id);

  @override
  Future<void> flush(String id) async {}
}

final conversationRepositoryProvider = Provider<ConversationRepository>((ref) {
  final api = ref.watch(backendApiProvider);
  ref.watch(backendUserIdProvider);
  if (api != null) return SupabaseConversationRepository(api);
  return MockConversationRepository(
    scenario: ref.watch(mockScenarioProvider),
    latency: ref.watch(mockLatencyProvider),
  );
});

const _uuid = Uuid();

/// All conversations, newest first. Holds the live state: the chat screen and
/// chat controller edit conversations through the methods here, which also
/// persist to the repository.
class ConversationsNotifier extends AsyncNotifier<List<Conversation>> {
  @override
  Future<List<Conversation>> build() =>
      ref.watch(conversationRepositoryProvider).list();

  ConversationRepository get _repo => ref.read(conversationRepositoryProvider);

  Conversation? find(String id) {
    for (final c in state.valueOrNull ?? const <Conversation>[]) {
      if (c.id == id) return c;
    }
    return null;
  }

  /// Applies [change] to one conversation. Keeps the list sorted by recency.
  void change(String id, Conversation Function(Conversation c) edit) {
    final list = state.valueOrNull;
    if (list == null) return;
    final i = list.indexWhere((c) => c.id == id);
    if (i < 0) return;
    final next = edit(list[i]);
    final copy = List.of(list)..[i] = next;
    copy.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    state = AsyncData(copy);
    _repo.save(next);
  }

  /// Saves anything still waiting (see [ConversationRepository.flush]).
  Future<void> flush(String id) => _repo.flush(id);

  /// Loads one conversation again from where it is stored (another device may
  /// have continued it). Anything still waiting to be saved goes first, and a
  /// chat that is being written right now is left alone.
  Future<void> reload(String id) async {
    await _repo.flush(id);
    final fresh = await _repo.byId(id);
    final list = state.valueOrNull;
    if (fresh == null || list == null) return;
    final i = list.indexWhere((c) => c.id == id);
    final copy = List.of(list);
    if (i < 0) {
      copy.add(fresh);
    } else {
      copy[i] = fresh;
    }
    copy.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    state = AsyncData(copy);
  }

  void setMode(String id, ChatMode mode) =>
      change(id, (c) => c.copyWith(mode: mode));

  void rename(String id, String title) =>
      change(id, (c) => c.copyWith(title: title));

  void togglePin(String id) => change(id, (c) => c.copyWith(pinned: !c.pinned));

  void setPersona(String id, String personaId) =>
      change(id, (c) => c.copyWith(personaId: personaId));

  void setArchived(String id, bool archived) =>
      change(id, (c) => c.copyWith(archived: archived));
  Future<void> delete(String id) async {
    final list = state.valueOrNull;
    if (list != null) state = AsyncData(list.where((c) => c.id != id).toList());
    await _repo.delete(id);
    // Its relationship events stay in the journal, marked "from a deleted chat".
    await ref.read(relationshipsProvider.notifier).markChatDeleted(id);
  }

  /// Starts a new chat with [character] (their greeting is already in it)
  /// and returns the new conversation id.
  String startNew(Character character, {DateTime? now}) {
    final id = _uuid.v4();
    final conv = Conversation(
      id: id,
      characterId: character.id,
      title: 'New chat with ${character.first}',
      updatedAt: now ?? DateTime.now(),
      mode: ref.read(appPrefsProvider).defaultMode,
      // Remember who you are in this chat (only a persona that really exists).
      personaId: () {
        final id = ref.read(activePersonaIdProvider);
        final list = ref.read(personasProvider).valueOrNull;
        return (list?.any((p) => p.id == id) ?? false) ? id : null;
      }(),
      messages: [
        Message(
          id: _uuid.v4(),
          role: MessageRole.ai,
          alts: [character.greeting],
        ),
      ],
    );
    final list = state.valueOrNull ?? const <Conversation>[];
    state = AsyncData([conv, ...list]);
    _repo.save(conv);
    return id;
  }
}

final conversationsProvider =
    AsyncNotifierProvider<ConversationsNotifier, List<Conversation>>(
      ConversationsNotifier.new,
    );

/// One conversation by id (null while loading or if it doesn't exist).
final conversationProvider = Provider.family<Conversation?, String>((ref, id) {
  final list = ref.watch(conversationsProvider).valueOrNull;
  if (list == null) return null;
  for (final c in list) {
    if (c.id == id) return c;
  }
  return null;
});
