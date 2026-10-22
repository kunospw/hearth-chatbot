import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hearth/features/relationship/domain/relationship_bands.dart';
import 'package:hearth/features/relationship/domain/relationship_engine.dart';
import 'package:hearth/features/relationship/domain/relationship_models.dart';

// The Dart engine is the reference for the server's TypeScript engine
// (supabase/functions/_shared/engine). Both run the SAME scenarios from
// supabase/tests/golden/scenarios.json and must produce the same result.
//
//   flutter test test/engine_golden_test.dart                       -> compares to expected.json
//   GENERATE_GOLDEN=1 flutter test test/engine_golden_test.dart     -> rewrites expected.json
//
// Regenerate only when the engine's behaviour is changed on purpose, and change
// the TypeScript port in the same commit. (The TS test is
// supabase/tests/engine_golden.test.ts, run with `node --test` in supabase/.)

const _dir = 'supabase/tests/golden';

void main() {
  final scenarios = (jsonDecode(File('$_dir/scenarios.json').readAsStringSync()) as List).cast<Map<String, dynamic>>();
  final generate = Platform.environment['GENERATE_GOLDEN'] == '1';
  final results = <Map<String, dynamic>>[for (final s in scenarios) _run(s)];

  if (generate) {
    File('$_dir/expected.json')
        .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(results));
  }

  test('golden file is up to date with the Dart engine', () {
    final expected = jsonDecode(File('$_dir/expected.json').readAsStringSync());
    expect(jsonDecode(jsonEncode(results)), expected);
  });
}

// ── runner ────────────────────────────────────────────────────────────────

Relationship _initial(Map<String, dynamic> setup) {
  // A relationship created at a starting point, as on first use.
  if (setup['start'] case final String start) {
    return startingRelationship(
      id: 'r',
      characterId: 'c',
      personaId: 'p',
      start: StartingPoint.values.byName(start),
    );
  }
  final preset = presetById(setup['preset'] as String);
  final v = (setup['values'] as Map<String, dynamic>?) ?? const {};
  var n = 0;
  return Relationship(
    id: 'r',
    characterId: 'c',
    personaId: 'p',
    type: RelationType.values.byName(setup['type'] as String),
    pacing: RelPacing.values.byName(setup['pacing'] as String),
    values: Values(
      trust: (v['trust'] ?? 20).toDouble(),
      affection: (v['affection'] ?? 15).toDouble(),
      attraction: (v['attraction'] ?? 0).toDouble(),
      tension: (v['tension'] ?? 0).toDouble(),
    ),
    stages: List.of(preset.stages),
    romanticFrom: preset.romanticFrom,
    stageIdx: (setup['stageIdx'] ?? 1) as int,
    facts: [
      for (final f in (setup['facts'] as List? ?? const []))
        Fact(
          id: 'init${n++}',
          text: f['text'] as String,
          locked: f['locked'] as bool,
          tags: RelationshipEngine.inferFactTags(f['text'] as String),
        ),
    ],
  );
}

Map<String, dynamic> _run(Map<String, dynamic> sc) {
  var r = _initial(sc['setup'] as Map<String, dynamic>);
  const engine = RelationshipEngine();
  var clock = DateTime.utc(2026, 3, 10, 9);
  final steps = <Map<String, dynamic>>[];
  final list = (sc['steps'] as List).cast<Map<String, dynamic>>();

  for (var i = 0; i < list.length; i++) {
    final s = list[i];
    final op = s['op'] as String;
    clock = clock.add(const Duration(minutes: 1));
    String outcome = 'ok';
    String? note;

    String describe(EngineOutcome o) {
      r = o.relationship;
      return switch (o) {
        Applied(note: final nt) => () {
            note = '${nt.text} | ${nt.story}';
            return 'applied';
          }(),
        Suggested(note: final nt) => () {
            note = '${nt.text} | ${nt.story}';
            return 'suggested';
          }(),
        Ignored(:final reason, :final counted) => 'ignored:${reason.name}:$counted',
      };
    }

    UserTurn turn(String id, String text) => UserTurn(
          messageId: id,
          text: text,
          now: clock,
          conversationId: s['conv'] as String?,
          chatTitle: 'Chat',
        );

    switch (op) {
      case 'user':
        outcome = describe(engine.processUserMessage(r, turn((s['message'] ?? 'm$i') as String, s['text'] as String)));
      case 'filler':
        for (var k = 0; k < (s['count'] as int); k++) {
          clock = clock.add(const Duration(minutes: 1));
          r = engine
              .processUserMessage(r, turn('f${i}_$k', 'just talking about the weather number $i $k'))
              .relationship;
        }
      case 'edit':
        outcome = describe(engine.reevaluateEdited(r, turn(s['message'] as String, s['text'] as String)));
      case 'proposal':
        outcome = describe(engine.processModelProposal(
          r,
          ModelProposal(
            kindId: s['kind'] as String,
            evidence: s['evidence'] as String,
            reason: s['reason'] as String,
            messageId: s['message'] as String,
            recentMessages: (s['recent'] as List).cast<String>(),
            now: clock,
            conversationId: s['conv'] as String?,
            chatTitle: 'Chat',
          ),
          characterFirst: 'Vesper',
        ));
      case 'undo':
        final e = r.events.where((e) => e.kindId == s['kind'] && e.canUndo).firstOrNull;
        if (e == null) {
          outcome = 'noop';
        } else {
          r = engine.undo(r, e.id, now: clock);
        }
      case 'accept':
        if (r.pending.isEmpty) {
          outcome = 'noop';
        } else {
          r = engine.acceptSuggestion(r, r.pending.first.id, now: clock);
        }
      case 'dismiss':
        if (r.pending.isEmpty) {
          outcome = 'noop';
        } else {
          r = engine.dismissSuggestion(r, r.pending.first.id);
        }
      case 'correct':
        final t = s['values'] as Map<String, dynamic>;
        r = engine.applyCorrection(
          r,
          Values(
            trust: t['trust'].toDouble(),
            affection: t['affection'].toDouble(),
            attraction: t['attraction'].toDouble(),
            tension: t['tension'].toDouble(),
          ),
          reason: s['reason'] as String?,
          now: clock,
        );
      case 'setType':
        r = engine.setType(r, RelationType.values.byName(s['type'] as String));
      case 'setPacing':
        r = engine.setPacing(r, RelPacing.values.byName(s['pacing'] as String));
      case 'preset':
        r = engine.applyPreset(r, presetById(s['id'] as String));
      case 'start':
        r = engine.applyStartingPoint(r, StartingPoint.values.byName(s['id'] as String), now: clock);
      case 'stages':
        r = engine.saveStages(r, (s['names'] as List).cast<String>(), s['current'] as int, s['lock'] as bool, now: clock);
      case 'addFact':
        r = engine.addFact(r, s['text'] as String, locked: s['locked'] as bool);
      case 'factLock':
        final f = r.facts.where((f) => f.text == s['text']).firstOrNull;
        if (f != null) r = engine.setFactLocked(r, f.id, s['locked'] as bool);
      case 'removeFact':
        final f = r.facts.where((f) => f.text == s['text']).firstOrNull;
        if (f != null) r = engine.removeFact(r, f.id);
      case 'deleteChat':
        r = engine.markChatDeleted(r, s['conv'] as String);
      case 'tick':
        clock = clock.add(Duration(minutes: s['minutes'] as int));
      case 'nextDay':
        clock = clock.add(const Duration(days: 1));
      default:
        throw StateError('unknown op $op');
    }
    steps.add({'op': op, 'outcome': outcome, 'note': note, 'state': _state(r)});
  }
  return {'name': sc['name'], 'steps': steps};
}

// ── normalised state (ids become #1, #2… in order of appearance) ──────────

double _n(num v) => (v * 1e9).round() / 1e9;

Map<String, dynamic> _state(Relationship r) {
  final ids = <String, String>{};
  String? id(String? x) => x == null ? null : ids.putIfAbsent(x, () => '#${ids.length + 1}');
  Map<String, dynamic> deltas(Map<RelValue, double> d) =>
      {for (final k in RelValue.values) if (d[k] != null) k.name: _n(d[k]!)};
  Map<String, dynamic> mults(Map<String, double> m) =>
      {for (final k in (m.keys.toList()..sort())) k: _n(m[k]!)};

  // ids first, in the order events / pending / facts are listed
  for (final e in r.events) {
    id(e.id);
  }
  for (final p in r.pending) {
    id(p.id);
  }
  for (final f in r.facts) {
    id(f.id);
  }
  return {
    'startingPoint': r.startingPoint.name,
    'type': r.type.name,
    'pacing': r.pacing.name,
    'values': {for (final k in RelValue.values) k.name: _n(r.values[k])},
    'stages': r.stages,
    'stageIdx': r.stageIdx,
    'stageLocked': r.stageLocked,
    'romanticFrom': r.romanticFrom,
    'turn': r.turn,
    'ignored': r.ignored,
    'recentHashes': r.recentHashes,
    'facts': [
      for (final f in r.facts) {'id': id(f.id), 'text': f.text, 'locked': f.locked, 'tags': f.tags},
    ],
    'events': [
      for (final e in r.events)
        {
          'id': id(e.id),
          'kindId': e.kindId,
          'category': e.category.name,
          'title': e.title,
          'at': e.at.toUtc().toIso8601String(),
          'why': e.why,
          'source': e.source.name,
          'deltas': deltas(e.deltas),
          'multipliers': mults(e.multipliers),
          'evidence': e.evidence,
          'chatTitle': e.chatTitle,
          'conversationId': e.conversationId,
          'messageId': e.messageId,
          'turn': e.turn,
          'stageBefore': e.stageBefore,
          'stageAfter': e.stageAfter,
          'undoable': e.undoable,
          'undoneBy': id(e.undoneBy),
          'undoOf': id(e.undoOf),
          'fromDeletedChat': e.fromDeletedChat,
        },
    ],
    'pending': [
      for (final p in r.pending)
        {
          'id': id(p.id),
          'kindId': p.kindId,
          'category': p.category.name,
          'title': p.title,
          'deltas': deltas(p.deltas),
          'multipliers': mults(p.multipliers),
          'why': p.why,
          'at': p.at.toUtc().toIso8601String(),
          'turn': p.turn,
          'chatTitle': p.chatTitle,
          'conversationId': p.conversationId,
          'messageId': p.messageId,
          'evidence': p.evidence,
          'source': p.source.name,
        },
    ],
  };
}
