import '../domain/relationship_models.dart';

// The relationship as the server sends it (relationship_snapshot(), and every
// answer of chat_turn / apply_correction). camelCase, same names as the models.

double _d(Object? v, [double fallback = 0]) =>
    v == null ? fallback : (v as num).toDouble();
int _i(Object? v) => (v as num).toInt();
String? _n(Object? v) => v as String?;

T _byName<T extends Enum>(List<T> values, Object? name, T fallback) =>
    values.asNameMap()[name] ?? fallback;

Map<RelValue, double> _deltas(Object? j) {
  final out = <RelValue, double>{};
  if (j is Map) {
    for (final k in RelValue.values) {
      if (j[k.name] != null) out[k] = _d(j[k.name]);
    }
  }
  return out;
}

Map<String, double> _mults(Object? j) =>
    j is Map ? {for (final e in j.entries) '${e.key}': _d(e.value)} : const {};

RelationshipEvent eventFromJson(Map<String, dynamic> j) => RelationshipEvent(
  id: j['id'] as String,
  kindId: _n(j['kindId']),
  category: _byName(TimelineKind.values, j['category'], TimelineKind.shift),
  title: (j['title'] as String?) ?? '',
  at: DateTime.tryParse('${j['at']}')?.toLocal() ?? DateTime.now(),
  why: (j['why'] as String?) ?? '',
  source: _byName(EventSource.values, j['source'], EventSource.engine),
  deltas: _deltas(j['deltas']),
  multipliers: _mults(j['multipliers']),
  evidence: _n(j['evidence']),
  chatTitle: (j['chatTitle'] as String?) ?? 'Story',
  conversationId: _n(j['conversationId']),
  messageId: _n(j['messageId']),
  turn: j['turn'] == null ? 0 : _i(j['turn']),
  stageBefore: j['stageBefore'] == null ? null : _i(j['stageBefore']),
  stageAfter: j['stageAfter'] == null ? null : _i(j['stageAfter']),
  undoable: j['undoable'] == true,
  undoneBy: _n(j['undoneBy']),
  undoOf: _n(j['undoOf']),
  fromDeletedChat: j['fromDeletedChat'] == true,
);

Suggestion suggestionFromJson(Map<String, dynamic> j) => Suggestion(
  id: j['id'] as String,
  kindId: (j['kindId'] as String?) ?? '',
  category: _byName(TimelineKind.values, j['category'], TimelineKind.shift),
  title: (j['title'] as String?) ?? '',
  deltas: _deltas(j['deltas']),
  why: (j['why'] as String?) ?? '',
  at: DateTime.tryParse('${j['at']}')?.toLocal() ?? DateTime.now(),
  turn: j['turn'] == null ? 0 : _i(j['turn']),
  chatTitle: (j['chatTitle'] as String?) ?? 'Story',
  conversationId: _n(j['conversationId']),
  messageId: _n(j['messageId']),
  evidence: _n(j['evidence']),
  multipliers: _mults(j['multipliers']),
  source: _byName(EventSource.values, j['source'], EventSource.engine),
);

/// Reads a relationship snapshot. The app only displays it: the engine and the
/// numbers live on the server, so the engine-internal parts (the ledger and
/// the repeat filter) are not needed here and stay empty.
Relationship relationshipFromJson(Map<String, dynamic> j) {
  final v = (j['values'] as Map?) ?? const {};
  return Relationship(
    id: j['id'] as String,
    characterId: j['characterId'] as String,
    personaId: j['personaId'] as String,
    universeId: _n(j['universeId']),
    startingPoint: _byName(
      StartingPoint.values,
      j['startingPoint'],
      StartingPoint.strangers,
    ),
    type: _byName(RelationType.values, j['type'], RelationType.undecided),
    pacing: _byName(RelPacing.values, j['pacing'], RelPacing.slow),
    values: Values(
      trust: _d(v['trust'], 20),
      affection: _d(v['affection'], 15),
      attraction: _d(v['attraction']),
      tension: _d(v['tension']),
    ),
    stages: [for (final s in (j['stages'] as List? ?? const [])) '$s'],
    stageIdx: j['stageIdx'] == null ? 0 : _i(j['stageIdx']),
    stageLocked: j['stageLocked'] == true,
    romanticFrom: j['romanticFrom'] == null ? null : _i(j['romanticFrom']),
    facts: [
      for (final f in (j['facts'] as List? ?? const []))
        Fact(
          id: (f as Map)['id'] as String,
          text: (f['text'] as String?) ?? '',
          locked: f['locked'] != false,
          tags: [for (final t in (f['tags'] as List? ?? const [])) '$t'],
        ),
    ],
    events: [
      for (final e in (j['events'] as List? ?? const []))
        eventFromJson(e as Map<String, dynamic>),
    ],
    pending: [
      for (final p in (j['pending'] as List? ?? const []))
        suggestionFromJson(p as Map<String, dynamic>),
    ],
    turn: j['turn'] == null ? 0 : _i(j['turn']),
    ignored: j['ignored'] == null ? 0 : _i(j['ignored']),
    version: j['version'] == null ? 0 : _i(j['version']),
  );
}
