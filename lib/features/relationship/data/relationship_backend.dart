import '../../../data/mock/mock_relationships.dart';
import '../domain/relationship_bands.dart';
import '../domain/relationship_engine.dart';
import '../domain/relationship_models.dart';

/// The result of evaluating a message: the new relationship, and the note to
/// show under the message (null when nothing counted).
class RelationshipUpdate {
  const RelationshipUpdate(this.relationship, this.note);
  final Relationship relationship;
  final RelationshipNote? note;
}

/// Everything the app may ask about relationships. **Values are owned by the
/// backend**: this interface has no way to set a number directly except
/// [correct] (your own correction, which the server records and re-bases).
///
/// Phase 6 replaces [MockRelationshipBackend] with one that calls the
/// `chat_turn` and `apply_correction` edge functions; no screen changes.
abstract interface class RelationshipBackend {
  /// The relationship for [characterId] as [personaId]. Created on first use
  /// at the character's [startingPoint] (the server reads it from the
  /// character itself).
  Future<Relationship> load(
    String characterId,
    String personaId, {
    String? universeId,
    StartingPoint startingPoint,
  });

  Future<RelationshipUpdate> userMessage({
    required String relationshipId,
    required String messageId,
    required String text,
    String? conversationId,
    String chatTitle,
  });

  /// A message you edited is evaluated again; its old effect is replaced.
  Future<RelationshipUpdate> editedMessage({
    required String relationshipId,
    required String messageId,
    required String text,
    String? conversationId,
    String chatTitle,
  });

  /// The character's own action, proposed by the model. Validated like any
  /// other event; numbers are never taken from the model.
  Future<RelationshipUpdate> modelProposal({
    required String relationshipId,
    required String messageId,
    required String kindId,
    required String evidence,
    required String reason,
    required List<String> recentMessages,
    required String characterFirst,
    String? conversationId,
    String chatTitle,
  });

  /// You switched back to a version of a reply whose character-side event
  /// was undone: count it again, validated afresh. (The server remembers what
  /// the model proposed for each version; the app never resubmits it.)
  Future<RelationshipUpdate> recountProposal(
    String relationshipId,
    String messageId,
    int altIndex,
  );

  Future<Relationship> undo(
    String relationshipId,
    String eventId, {
    String? reason,
  });
  Future<Relationship> acceptSuggestion(
    String relationshipId,
    String suggestionId,
  );
  Future<Relationship> dismissSuggestion(
    String relationshipId,
    String suggestionId,
  );
  Future<Relationship> correct(
    String relationshipId,
    Values values, {
    String? reason,
  });
  Future<Relationship> setType(String relationshipId, RelationType type);
  Future<Relationship> setPacing(String relationshipId, RelPacing pacing);
  Future<Relationship> applyPreset(String relationshipId, String presetId);

  /// Starts over from [start]: kind, stages, pacing and values (logged).
  Future<Relationship> setStartingPoint(
    String relationshipId,
    StartingPoint start,
  );
  Future<Relationship> saveStages(
    String relationshipId,
    List<String> names,
    int current,
    bool lock,
  );
  Future<Relationship> addFact(
    String relationshipId,
    String text, {
    bool locked,
  });
  Future<Relationship> setFactLocked(
    String relationshipId,
    String factId,
    bool locked,
  );
  Future<Relationship> removeFact(String relationshipId, String factId);

  /// Events from [conversationId] stay in the timeline, marked "from a deleted chat".
  Future<List<Relationship>> markChatDeleted(String conversationId);
}

/// In-memory stand-in that runs the Dart engine. For the mock phase only.
class MockRelationshipBackend implements RelationshipBackend {
  MockRelationshipBackend({
    DateTime Function()? clock,
    this.engine = const RelationshipEngine(),
  }) : _now = clock ?? DateTime.now;

  final RelationshipEngine engine;
  final DateTime Function() _now;
  final Map<String, Relationship> _byId = {};

  Relationship _get(String id) => _byId[id]!;

  Relationship _save(Relationship r) => _byId[r.id] = r;

  @override
  Future<Relationship> load(
    String characterId,
    String personaId, {
    String? universeId,
    StartingPoint startingPoint = StartingPoint.strangers,
  }) async {
    final id = 'rel-$characterId-$personaId';
    return _byId.putIfAbsent(
      id,
      () => seedRelationship(
        characterId: characterId,
        personaId: personaId,
        now: _now(),
        universeId: universeId,
        startingPoint: startingPoint,
      ),
    );
  }

  RelationshipUpdate _outcome(EngineOutcome o) {
    final saved = _save(o.relationship);
    return switch (o) {
      Applied(:final note) => RelationshipUpdate(saved, note),
      Suggested(:final note) => RelationshipUpdate(saved, note),
      Ignored() => RelationshipUpdate(saved, null),
    };
  }

  @override
  Future<RelationshipUpdate> userMessage({
    required String relationshipId,
    required String messageId,
    required String text,
    String? conversationId,
    String chatTitle = 'Story',
  }) async => _outcome(
    engine.processUserMessage(
      _get(relationshipId),
      UserTurn(
        messageId: messageId,
        text: text,
        now: _now(),
        conversationId: conversationId,
        chatTitle: chatTitle,
      ),
    ),
  );

  @override
  Future<RelationshipUpdate> editedMessage({
    required String relationshipId,
    required String messageId,
    required String text,
    String? conversationId,
    String chatTitle = 'Story',
  }) async => _outcome(
    engine.reevaluateEdited(
      _get(relationshipId),
      UserTurn(
        messageId: messageId,
        text: text,
        now: _now(),
        conversationId: conversationId,
        chatTitle: chatTitle,
      ),
    ),
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
  }) async => _outcome(
    engine.processModelProposal(
      _get(relationshipId),
      ModelProposal(
        kindId: kindId,
        evidence: evidence,
        reason: reason,
        messageId: messageId,
        recentMessages: recentMessages,
        now: _now(),
        conversationId: conversationId,
        chatTitle: chatTitle,
      ),
      characterFirst: characterFirst,
    ),
  );

  @override
  Future<RelationshipUpdate> recountProposal(
    String relationshipId,
    String messageId,
    int altIndex,
  ) async => RelationshipUpdate(_get(relationshipId), null);

  @override
  Future<Relationship> undo(
    String relationshipId,
    String eventId, {
    String? reason,
  }) async => _save(
    engine.undo(_get(relationshipId), eventId, now: _now(), reason: reason),
  );

  @override
  Future<Relationship> acceptSuggestion(
    String relationshipId,
    String suggestionId,
  ) async => _save(
    engine.acceptSuggestion(_get(relationshipId), suggestionId, now: _now()),
  );

  @override
  Future<Relationship> dismissSuggestion(
    String relationshipId,
    String suggestionId,
  ) async =>
      _save(engine.dismissSuggestion(_get(relationshipId), suggestionId));

  @override
  Future<Relationship> correct(
    String relationshipId,
    Values values, {
    String? reason,
  }) async => _save(
    engine.applyCorrection(
      _get(relationshipId),
      values,
      reason: reason,
      now: _now(),
    ),
  );

  @override
  Future<Relationship> setType(
    String relationshipId,
    RelationType type,
  ) async => _save(engine.setType(_get(relationshipId), type));

  @override
  Future<Relationship> setPacing(
    String relationshipId,
    RelPacing pacing,
  ) async => _save(engine.setPacing(_get(relationshipId), pacing));

  @override
  Future<Relationship> applyPreset(
    String relationshipId,
    String presetId,
  ) async =>
      _save(engine.applyPreset(_get(relationshipId), presetById(presetId)));

  @override
  Future<Relationship> setStartingPoint(
    String relationshipId,
    StartingPoint start,
  ) async => _save(
    engine.applyStartingPoint(_get(relationshipId), start, now: _now()),
  );

  @override
  Future<Relationship> saveStages(
    String relationshipId,
    List<String> names,
    int current,
    bool lock,
  ) async => _save(
    engine.saveStages(_get(relationshipId), names, current, lock, now: _now()),
  );

  @override
  Future<Relationship> addFact(
    String relationshipId,
    String text, {
    bool locked = true,
  }) async => _save(engine.addFact(_get(relationshipId), text, locked: locked));

  @override
  Future<Relationship> setFactLocked(
    String relationshipId,
    String factId,
    bool locked,
  ) async => _save(engine.setFactLocked(_get(relationshipId), factId, locked));

  @override
  Future<Relationship> removeFact(String relationshipId, String factId) async =>
      _save(engine.removeFact(_get(relationshipId), factId));

  @override
  Future<List<Relationship>> markChatDeleted(String conversationId) async => [
    for (final id in _byId.keys.toList())
      _save(engine.markChatDeleted(_byId[id]!, conversationId)),
  ];
}
