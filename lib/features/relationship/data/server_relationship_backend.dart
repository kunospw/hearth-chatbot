import '../../../core/backend/backend_api.dart';
import '../../../core/backend/mappers.dart';
import '../domain/relationship_models.dart';
import 'relationship_backend.dart';
import 'relationship_json.dart';

/// The relationship backend on the server. The app only asks:
///
///  * reading goes through the `ensure_relationship` database function (RLS
///    shows you only your own),
///  * everything you can do from the journal goes to the `apply_correction`
///    edge function, which runs the engine and answers with the new state,
///  * your messages and the model's proposals are judged inside `chat_turn`
///    while the reply is written, so there is nothing to call for them here.
///
/// No number is ever computed or written on the device.
class ServerRelationshipBackend implements RelationshipBackend {
  ServerRelationshipBackend(this.api);

  final BackendApi api;

  @override
  Future<Relationship> load(
    String characterId,
    String personaId, {
    String? universeId,
  }) async {
    final j = await api.rpc('ensure_relationship', {
      'p_character': characterId,
      'p_persona': personaId,
    });
    return relationshipFromJson(Map<String, dynamic>.from(j as Map));
  }

  Future<RelationshipUpdate> _act(
    String action,
    String relationshipId, [
    Map<String, Object?> extra = const {},
  ]) async {
    final res = await api.invoke('apply_correction', {
      'action': action,
      'relationshipId': relationshipId,
      ...extra,
    });
    final note = res['note'];
    return RelationshipUpdate(
      relationshipFromJson(
        Map<String, dynamic>.from(res['relationship'] as Map),
      ),
      note is Map ? noteFromJson(Map<String, dynamic>.from(note)) : null,
    );
  }

  Future<Relationship> _rel(Future<RelationshipUpdate> u) async =>
      (await u).relationship;

  // ── judged inside chat_turn ─────────────────────────────────────────────

  @override
  Future<RelationshipUpdate> userMessage({
    required String relationshipId,
    required String messageId,
    required String text,
    String? conversationId,
    String chatTitle = 'Story',
  }) => throw UnsupportedError(
    'The server judges your message inside chat_turn.',
  );

  @override
  Future<RelationshipUpdate> modelProposal({
    required String relationshipId,
    required String messageId,
    required String kindId,
    required String evidence,
    required String reason,
    required List<String> recentMessages,
    required String characterFirst,
    String? conversationId,
    String chatTitle = 'Story',
  }) => throw UnsupportedError(
    'The model proposes inside chat_turn; the app never submits a proposal.',
  );

  // ── from the chat ───────────────────────────────────────────────────────

  /// The server reads the edited text from your saved message (so flush first).
  @override
  Future<RelationshipUpdate> editedMessage({
    required String relationshipId,
    required String messageId,
    required String text,
    String? conversationId,
    String chatTitle = 'Story',
  }) => _act('reevaluate_message', relationshipId, {'messageId': messageId});

  @override
  Future<RelationshipUpdate> recountProposal(
    String relationshipId,
    String messageId,
    int altIndex,
  ) => _act('recount_proposal', relationshipId, {
    'messageId': messageId,
    'altIndex': altIndex,
  });

  // ── from the journal ────────────────────────────────────────────────────

  @override
  Future<Relationship> undo(
    String relationshipId,
    String eventId, {
    String? reason,
  }) => _rel(
    _act('undo', relationshipId, {'eventId': eventId, 'reason': ?reason}),
  );

  @override
  Future<Relationship> acceptSuggestion(
    String relationshipId,
    String suggestionId,
  ) => _rel(
    _act('accept_suggestion', relationshipId, {'suggestionId': suggestionId}),
  );

  @override
  Future<Relationship> dismissSuggestion(
    String relationshipId,
    String suggestionId,
  ) => _rel(
    _act('dismiss_suggestion', relationshipId, {'suggestionId': suggestionId}),
  );

  @override
  Future<Relationship> correct(
    String relationshipId,
    Values values, {
    String? reason,
  }) => _rel(
    _act('correct', relationshipId, {
      'values': {
        'trust': values.trust,
        'affection': values.affection,
        'attraction': values.attraction,
        'tension': values.tension,
      },
      'reason': ?reason,
    }),
  );

  @override
  Future<Relationship> setType(String relationshipId, RelationType type) =>
      _rel(_act('set_type', relationshipId, {'type': type.name}));

  @override
  Future<Relationship> setPacing(String relationshipId, RelPacing pacing) =>
      _rel(_act('set_pacing', relationshipId, {'pacing': pacing.name}));

  @override
  Future<Relationship> applyPreset(String relationshipId, String presetId) =>
      _rel(_act('apply_preset', relationshipId, {'presetId': presetId}));

  @override
  Future<Relationship> saveStages(
    String relationshipId,
    List<String> names,
    int current,
    bool lock,
  ) => _rel(
    _act('save_stages', relationshipId, {
      'names': names,
      'current': current,
      'lock': lock,
    }),
  );

  @override
  Future<Relationship> addFact(
    String relationshipId,
    String text, {
    bool locked = true,
  }) =>
      _rel(_act('add_fact', relationshipId, {'text': text, 'locked': locked}));

  @override
  Future<Relationship> setFactLocked(
    String relationshipId,
    String factId,
    bool locked,
  ) => _rel(
    _act('set_fact_locked', relationshipId, {
      'factId': factId,
      'locked': locked,
    }),
  );

  @override
  Future<Relationship> removeFact(String relationshipId, String factId) =>
      _rel(_act('remove_fact', relationshipId, {'factId': factId}));

  /// A database trigger marks the events when a chat is deleted. The app
  /// reloads the relationships it has open afterwards.
  @override
  Future<List<Relationship>> markChatDeleted(String conversationId) async =>
      const [];
}
