// Relationship seeds transcribed from prototype/Main.dc.html (`seedRel`).
import '../../features/relationship/domain/relationship_bands.dart';
import '../../features/relationship/domain/relationship_models.dart';

/// The starting relationship for a character (as seen by [personaId]).
/// Characters without a seed begin at their [startingPoint] (a fresh
/// friendship arc when you have just met).
Relationship seedRelationship({
  required String characterId,
  required String personaId,
  required DateTime now,
  String? universeId,
  StartingPoint startingPoint = StartingPoint.strangers,
}) {
  final id = 'rel-$characterId-$personaId';
  final romance = presetById('romance');
  final friendship = presetById('friendship');
  final rivalry = presetById('rivalry');
  DateTime ago({int days = 0, int minutes = 0}) =>
      now.subtract(Duration(days: days, minutes: minutes));

  switch (characterId) {
    case 'vesper':
      return Relationship(
        id: id,
        characterId: characterId,
        personaId: personaId,
        universeId: universeId,
        type: RelationType.undecided,
        pacing: RelPacing.slow,
        values: const Values(
          trust: 31.5,
          affection: 22,
          attraction: 6,
          tension: 14,
        ),
        stages: List.of(romance.stages),
        romanticFrom: romance.romanticFrom,
        stageIdx: 1,
        turn: 14,
        ignored: 2,
        facts: const [
          Fact(
            id: 'vf1',
            text: 'Vesper has never told anyone about the bell.',
            tags: ['secret'],
          ),
          Fact(
            id: 'vf2',
            text: 'You are not related to Vesper, whatever the letters say.',
          ),
        ],
        ledger: [
          LedgerEntry(
            kindId: 'promise_made',
            turn: 14,
            at: ago(minutes: 2),
            deltas: const {RelValue.trust: 2},
            eventId: 'e5',
          ),
        ],
        events: [
          RelationshipEvent(
            id: 'e5',
            kindId: 'promise_made',
            category: TimelineKind.shift,
            title: 'You gave your word about the letters',
            chatTitle: 'The letter from the north tide',
            conversationId: 'c1',
            messageId: 'c1d',
            at: ago(minutes: 2),
            turn: 14,
            deltas: const {RelValue.trust: 2},
            multipliers: const {'pacing': 0.5},
            why:
                'Matched “a promise” in your message: “I promise I won’t open any of them without you…”. '
                'Slow-burn pacing halves gains: Trust +4 → +2.',
            source: EventSource.engine,
            undoable: true,
          ),
          RelationshipEvent(
            id: 'e4',
            category: TimelineKind.milestone,
            title: 'Stage reached: Wary Acquaintances',
            chatTitle: 'The letter from the north tide',
            conversationId: 'c1',
            at: ago(days: 1),
            why:
                'Trust and affection, minus tension, passed this stage’s threshold. '
                'Tension from the logbook held it back for two scenes.',
            source: EventSource.engine,
          ),
          RelationshipEvent(
            id: 'e3',
            kindId: 'apology',
            category: TimelineKind.reconcile,
            title: 'You returned her father’s logbook and apologised',
            chatTitle: 'The letter from the north tide',
            conversationId: 'c1',
            at: ago(days: 1),
            deltas: const {RelValue.trust: 1, RelValue.tension: -4},
            why: 'Matched “an apology”. Repairs ease tension faster than they rebuild trust.',
            source: EventSource.engine,
            undoable: true,
          ),
          RelationshipEvent(
            id: 'e2',
            kindId: 'boundary_crossed',
            category: TimelineKind.setback,
            title: 'You read her father’s logbook without asking',
            chatTitle: 'The letter from the north tide',
            conversationId: 'c1',
            at: ago(days: 8),
            deltas: const {RelValue.trust: -3, RelValue.tension: 8},
            why: 'Matched “crossed a boundary”. In Slow burn, setbacks are softened less than gains (×0.75).',
            source: EventSource.engine,
            undoable: true,
          ),
          RelationshipEvent(
            id: 'e1',
            category: TimelineKind.milestone,
            title: 'First meeting at the lighthouse',
            chatTitle: 'The letter from the north tide',
            conversationId: 'c1',
            at: ago(days: 15),
            why: 'Starting point you chose when the story began: Strangers, Trust 20.',
            source: EventSource.user,
          ),
        ],
      );
    case 'jun':
      return Relationship(
        id: id,
        characterId: characterId,
        personaId: personaId,
        universeId: universeId,
        type: RelationType.platonic,
        pacing: RelPacing.balanced,
        values: const Values(
          trust: 44,
          affection: 41,
          attraction: 0,
          tension: 8,
        ),
        stages: List.of(friendship.stages),
        stageIdx: 2,
        turn: 6,
        facts: const [
          Fact(
            id: 'jf1',
            text: 'Jun calls you “Parcel”. Nobody else is allowed to.',
          ),
        ],
        events: [
          RelationshipEvent(
            id: 'j2',
            category: TimelineKind.milestone,
            title: 'Stage reached: Allies',
            chatTitle: 'Rooftop delivery',
            conversationId: 'c2',
            at: ago(days: 1),
            why: 'Trust and affection passed the Allies threshold after the canal chase.',
            source: EventSource.engine,
          ),
          RelationshipEvent(
            id: 'j1',
            category: TimelineKind.milestone,
            title: 'Met on the Exchange steps',
            chatTitle: 'Rooftop delivery',
            conversationId: 'c2',
            at: ago(days: 1),
            why: 'Starting point: Acquaintances, Trust 35.',
            source: EventSource.user,
          ),
        ],
      );
    case 'morrow':
      return Relationship(
        id: id,
        characterId: characterId,
        personaId: personaId,
        universeId: universeId,
        type: RelationType.other,
        pacing: RelPacing.slow,
        values: const Values(
          trust: 30,
          affection: 25,
          attraction: 0,
          tension: 2,
        ),
        stages: const [
          'Visitor',
          'Reader',
          'Regular',
          'Trusted Reader',
          'Apprentice Archivist',
          'Keeper of the Stacks',
        ],
        stageIdx: 1,
        turn: 4,
        events: [
          RelationshipEvent(
            id: 'm1',
            category: TimelineKind.milestone,
            title: 'You borrowed your first book',
            chatTitle: 'The bookmark in 1612',
            conversationId: 'c3',
            at: ago(days: 4),
            why: 'Starting point: Reader. These stages were written for this character.',
            source: EventSource.user,
          ),
        ],
      );
    case 'iselde':
      return Relationship(
        id: id,
        characterId: characterId,
        personaId: personaId,
        universeId: universeId,
        startingPoint: StartingPoint.rivals,
        type: RelationType.rivalrous,
        pacing: RelPacing.slow,
        values: const Values(
          trust: 12,
          affection: 15,
          attraction: 0,
          tension: 40,
        ),
        stages: List.of(rivalry.stages),
        stageIdx: 0,
        events: [
          RelationshipEvent(
            id: 'i1',
            category: TimelineKind.milestone,
            title: 'Crossed blades in the poetry aisle',
            chatTitle: 'Not started',
            at: ago(days: 30),
            why: 'Starting point from the character’s scenario: Rivals.',
            source: EventSource.setup,
          ),
        ],
      );
  }
  return startingRelationship(
    id: id,
    characterId: characterId,
    personaId: personaId,
    universeId: universeId,
    start: startingPoint,
  );
}
