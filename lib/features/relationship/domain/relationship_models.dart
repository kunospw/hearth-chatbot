import 'package:flutter/foundation.dart';

/// The four values every relationship tracks. Numbers are never shown in a chat.
enum RelValue {
  trust('Trust', 'Will they rely on you, confide in you, follow your lead?'),
  affection(
    'Affection',
    'Warmth and fondness — friendly, familial or romantic.',
  ),
  attraction(
    'Attraction',
    'Romantic interest. Only used when the relationship allows it.',
  ),
  tension(
    'Tension',
    'Unresolved friction. High tension makes them guarded or combative.',
  );

  const RelValue(this.label, this.help);
  final String label;
  final String help;
}

enum RelationType {
  undecided('Let the story decide'),
  platonic('Platonic'),
  romantic('Romantic'),
  familial('Family'),
  rivalrous('Rivalry'),
  other('Something else');

  const RelationType(this.label);
  final String label;

  /// Romance is only possible when the type is Romantic or Let the story decide.
  bool get romanceAllowed => this == romantic || this == undecided;
}

enum RelPacing {
  slow(
    'Slow burn',
    0.5,
    0.75,
    'Small steps. Big moments still count, but feelings take many scenes to change. '
        'Setbacks land harder than gains.',
  ),
  balanced(
    'Balanced',
    1,
    1,
    'Meaningful moments move things at a natural, story-like pace.',
  ),
  fast('Fast', 1.6, 1.2, 'Bonds form quickly. Good for short adventures.'),
  manual(
    'Manual',
    1,
    1,
    'Nothing changes on its own. The story suggests changes here, and you approve them.',
  );

  const RelPacing(this.label, this.up, this.down, this.hint);
  final String label;

  /// Multiplier for gains / for setbacks.
  final double up;
  final double down;
  final String hint;
}

/// Where the story between you begins. Picked for a character in the editor
/// (every new relationship with them starts here) and changeable later in the
/// journal. Each one sets the kind, the stage arc and stage, the pacing and the
/// four values (`startingSetups` in relationship_bands.dart).
enum StartingPoint {
  strangers(
    'Just met',
    'You meet for the first time. Everything is still ahead of you.',
  ),
  friends(
    'Friends',
    'Already friends: easy trust and shared history, no first-meeting awkwardness.',
  ),
  together(
    'Together',
    'Already a couple: dating, engaged or married. Romance is there from the first message.',
  ),
  family('Family', 'Already family, and close. Romance is off.'),
  rivals(
    'Rivals',
    'Old rivals with a score to settle. Expect sparks and sharp words.',
  );

  const StartingPoint(this.label, this.hint);
  final String label;
  final String hint;
}

/// How a moment shows in the timeline.
enum TimelineKind {
  milestone('Milestone'),
  setback('Setback'),
  reconcile('Reconciliation'),
  shift('Small shift'),
  correction('Your correction');

  const TimelineKind(this.label);
  final String label;
}

enum EventSource {
  engine('Story engine'),
  modelProposal('Story engine · the character’s own action'),
  user('You'),
  undo('You (undo)'),
  approved('Story suggestion · approved by you'),
  setup('Character setup');

  const EventSource(this.label);
  final String label;
}

/// A reading of the four values.
@immutable
class Values {
  const Values({
    this.trust = 20,
    this.affection = 15,
    this.attraction = 0,
    this.tension = 0,
  });

  final double trust;
  final double affection;
  final double attraction;
  final double tension;

  double operator [](RelValue v) => switch (v) {
    RelValue.trust => trust,
    RelValue.affection => affection,
    RelValue.attraction => attraction,
    RelValue.tension => tension,
  };

  Values withValue(RelValue v, double x) => switch (v) {
    RelValue.trust => copyWith(trust: x),
    RelValue.affection => copyWith(affection: x),
    RelValue.attraction => copyWith(attraction: x),
    RelValue.tension => copyWith(tension: x),
  };

  Values copyWith({
    double? trust,
    double? affection,
    double? attraction,
    double? tension,
  }) => Values(
    trust: trust ?? this.trust,
    affection: affection ?? this.affection,
    attraction: attraction ?? this.attraction,
    tension: tension ?? this.tension,
  );

  /// Adds [deltas], keeping every value between 0 and 100.
  Values plus(Map<RelValue, double> deltas) {
    var out = this;
    deltas.forEach(
      (k, d) => out = out.withValue(k, (out[k] + d).clamp(0, 100).toDouble()),
    );
    return out;
  }

  @override
  bool operator ==(Object other) =>
      other is Values &&
      other.trust == trust &&
      other.affection == affection &&
      other.attraction == attraction &&
      other.tension == tension;

  @override
  int get hashCode => Object.hash(trust, affection, attraction, tension);

  @override
  String toString() => 'Values(t$trust a$affection x$attraction n$tension)';
}

/// Something that must always stay true between you. A locked fact is never
/// contradicted by the AI or by the engine; [tags] decide what contradicts it.
@immutable
class Fact {
  const Fact({
    required this.id,
    required this.text,
    this.locked = true,
    this.tags = const [],
  });

  final String id;
  final String text;
  final bool locked;
  final List<String> tags;

  Fact copyWith({String? text, bool? locked, List<String>? tags}) => Fact(
    id: id,
    text: text ?? this.text,
    locked: locked ?? this.locked,
    tags: tags ?? this.tags,
  );
}

/// One entry in the timeline. The log is append-only: an undo adds a reversing
/// event and strikes the original through ([undoneBy]); nothing is deleted.
@immutable
class RelationshipEvent {
  const RelationshipEvent({
    required this.id,
    required this.category,
    required this.title,
    required this.at,
    required this.why,
    required this.source,
    this.kindId,
    this.deltas = const {},
    this.multipliers = const {},
    this.evidence,
    this.chatTitle = 'Story',
    this.conversationId,
    this.messageId,
    this.turn = 0,
    this.stageBefore,
    this.stageAfter,
    this.undoable = false,
    this.undoneBy,
    this.undoOf,
    this.fromDeletedChat = false,
  });

  final String id;

  /// A catalogue kind (`promise_made`…), or null for milestones and corrections.
  final String? kindId;
  final TimelineKind category;
  final String title;
  final DateTime at;
  final String why;
  final EventSource source;
  final Map<RelValue, double> deltas;

  /// What changed the raw amount, e.g. `{'pacing': 0.5, 'repeat': 0.67}`.
  final Map<String, double> multipliers;
  final String? evidence;
  final String chatTitle;
  final String? conversationId;
  final String? messageId;
  final int turn;
  final int? stageBefore;
  final int? stageAfter;
  final bool undoable;

  /// Id of the event that reversed this one.
  final String? undoneBy;

  /// Set on a reversing event: the event it undoes.
  final String? undoOf;
  final bool fromDeletedChat;

  bool get isUndone => undoneBy != null;
  bool get canUndo => undoable && !isUndone;

  RelationshipEvent copyWith({String? undoneBy, bool? fromDeletedChat}) =>
      RelationshipEvent(
        id: id,
        kindId: kindId,
        category: category,
        title: title,
        at: at,
        why: why,
        source: source,
        deltas: deltas,
        multipliers: multipliers,
        evidence: evidence,
        chatTitle: chatTitle,
        conversationId: conversationId,
        messageId: messageId,
        turn: turn,
        stageBefore: stageBefore,
        stageAfter: stageAfter,
        undoable: undoable,
        undoneBy: undoneBy ?? this.undoneBy,
        undoOf: undoOf,
        fromDeletedChat: fromDeletedChat ?? this.fromDeletedChat,
      );
}

/// A change waiting for approval (Manual pacing).
@immutable
class Suggestion {
  const Suggestion({
    required this.id,
    required this.kindId,
    required this.category,
    required this.title,
    required this.deltas,
    required this.why,
    required this.at,
    required this.turn,
    this.chatTitle = 'Story',
    this.conversationId,
    this.messageId,
    this.evidence,
    this.multipliers = const {},
    this.source = EventSource.engine,
  });

  final String id;
  final String kindId;
  final TimelineKind category;
  final String title;
  final Map<RelValue, double> deltas;
  final String why;
  final DateTime at;
  final int turn;
  final String chatTitle;
  final String? conversationId;
  final String? messageId;
  final String? evidence;
  final Map<String, double> multipliers;
  final EventSource source;
}

/// A moment that counted (or is waiting to). Cooldowns, diminishing returns and
/// the scene and daily budgets are all derived from this ledger, so undoing an
/// event frees its cooldown and budget again.
@immutable
class LedgerEntry {
  const LedgerEntry({
    required this.kindId,
    required this.turn,
    required this.at,
    required this.deltas,
    this.eventId,
    this.suggestionId,
  });

  final String kindId;
  final int turn;
  final DateTime at;
  final Map<RelValue, double> deltas;
  final String? eventId;
  final String? suggestionId;

  double get magnitude => deltas.values.fold(0.0, (s, d) => s + d.abs());
}

/// The relationship between you (as a persona) and one character in one
/// universe. Values are owned by the backend; the app only displays them.
@immutable
class Relationship {
  const Relationship({
    required this.id,
    required this.characterId,
    required this.personaId,
    required this.stages,
    this.universeId,
    this.startingPoint = StartingPoint.strangers,
    this.type = RelationType.undecided,
    this.pacing = RelPacing.slow,
    this.values = const Values(),
    this.stageIdx = 1,
    this.stageLocked = false,
    this.romanticFrom,
    this.facts = const [],
    this.events = const [],
    this.pending = const [],
    this.ledger = const [],
    this.recentHashes = const [],
    this.turn = 0,
    this.ignored = 0,
    this.version = 0,
  });

  final String id;
  final String characterId;
  final String personaId;
  final String? universeId;

  /// Where the story began (the model is told, so a couple or old friends
  /// never act like a first meeting).
  final StartingPoint startingPoint;
  final RelationType type;
  final RelPacing pacing;
  final Values values;

  /// Six stage names (they belong to this relationship).
  final List<String> stages;
  final int stageIdx;
  final bool stageLocked;

  /// The first stage that needs romance (attraction) to be reached.
  final int? romanticFrom;
  final List<Fact> facts;

  /// Newest first.
  final List<RelationshipEvent> events;
  final List<Suggestion> pending;
  final List<LedgerEntry> ledger;

  /// Normalised text of recent user messages as `turn|text`, for the repeat filter.
  final List<String> recentHashes;

  /// User turns seen so far.
  final int turn;

  /// Small moments that didn't count (shown as a note in the journal).
  final int ignored;

  /// Optimistic-locking counter; bumped by every change.
  final int version;

  String get stageName => stages[stageIdx.clamp(0, stages.length - 1)];

  Relationship copyWith({
    StartingPoint? startingPoint,
    RelationType? type,
    RelPacing? pacing,
    Values? values,
    List<String>? stages,
    int? stageIdx,
    bool? stageLocked,
    int? romanticFrom,
    bool clearRomanticFrom = false,
    List<Fact>? facts,
    List<RelationshipEvent>? events,
    List<Suggestion>? pending,
    List<LedgerEntry>? ledger,
    List<String>? recentHashes,
    int? turn,
    int? ignored,
  }) => Relationship(
    id: id,
    characterId: characterId,
    personaId: personaId,
    universeId: universeId,
    startingPoint: startingPoint ?? this.startingPoint,
    type: type ?? this.type,
    pacing: pacing ?? this.pacing,
    values: values ?? this.values,
    stages: stages ?? this.stages,
    stageIdx: stageIdx ?? this.stageIdx,
    stageLocked: stageLocked ?? this.stageLocked,
    romanticFrom: clearRomanticFrom
        ? null
        : (romanticFrom ?? this.romanticFrom),
    facts: facts ?? this.facts,
    events: events ?? this.events,
    pending: pending ?? this.pending,
    ledger: ledger ?? this.ledger,
    recentHashes: recentHashes ?? this.recentHashes,
    turn: turn ?? this.turn,
    ignored: ignored ?? this.ignored,
    version: version + 1,
  );
}

/// The one line shown under a message when something shifted. Never numbers.
@immutable
class RelationshipNote {
  const RelationshipNote({
    required this.text,
    required this.story,
    this.entryId,
    this.kindId,
    this.evidence,
    this.reason,
  });

  /// Chat mode: "Trust grew a little".
  final String text;

  /// Story mode: "Something shifted between you."
  final String story;

  /// The timeline entry to open (null for a suggestion waiting for approval).
  final String? entryId;

  /// For a character-side event: what the model proposed (so switching back to
  /// that version of the reply can count it again).
  final String? kindId;
  final String? evidence;
  final String? reason;
}
