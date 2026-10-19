import 'package:flutter_test/flutter_test.dart';
import 'package:hearth/data/mock/mock_relationships.dart';
import 'package:hearth/features/relationship/domain/event_catalogue.dart';
import 'package:hearth/features/relationship/domain/relationship_bands.dart';
import 'package:hearth/features/relationship/domain/relationship_engine.dart';
import 'package:hearth/features/relationship/domain/relationship_models.dart';

const engine = RelationshipEngine();
final t0 = DateTime(2026, 10, 17, 12);

/// A relationship on the romance arc, balanced pacing unless told otherwise.
Relationship rel({
  Values values = const Values(trust: 30, affection: 20, attraction: 0, tension: 0),
  RelPacing pacing = RelPacing.balanced,
  RelationType type = RelationType.undecided,
  int stageIdx = 1,
  bool locked = false,
  int? romanticFrom = 4,
  List<Fact> facts = const [],
}) {
  final p = presetById(romanticFrom == null ? 'friendship' : 'romance');
  return Relationship(
    id: 'r',
    characterId: 'vesper',
    personaId: 'wren',
    type: type,
    pacing: pacing,
    values: values,
    stages: List.of(p.stages),
    stageIdx: stageIdx,
    stageLocked: locked,
    romanticFrom: romanticFrom,
    facts: facts,
  );
}

/// Feeds user messages one by one, keeping the relationship moving forward.
class Run {
  Run(this.r);
  Relationship r;
  int n = 0;
  EngineOutcome? last;
  DateTime clock = t0;

  EngineOutcome say(String text, {Duration? after}) {
    n++;
    clock = clock.add(after ?? const Duration(minutes: 1));
    last = engine.processUserMessage(
      r,
      UserTurn(messageId: 'm$n', text: text, now: clock, chatTitle: 'Test chat'),
    );
    r = last!.relationship;
    return last!;
  }

  /// Turns that match nothing and change nothing.
  void quiet(int turns) {
    for (var i = 0; i < turns; i++) {
      say('The tide keeps coming in, number $i, again');
    }
  }

  RelationshipEvent get event => (last as Applied).event;
}

/// Values whose stage score is exactly [s] (trust and affection only).
Values atScore(double s) => s <= 60
    ? Values(trust: s / 0.6, affection: 0, attraction: 0, tension: 0)
    : Values(trust: 100, affection: (s - 60) / 0.4, attraction: 0, tension: 0);

void main() {
  group('stage maths', () {
    test('score = 0.6·trust + 0.4·affection − 0.3·tension', () {
      expect(stageScore(const Values(trust: 31.5, affection: 22, attraction: 6, tension: 14)),
          closeTo(23.5, 1e-9));
      expect(stageScore(const Values(trust: 50, affection: 50, tension: 100)), closeTo(20, 1e-9));
    });

    test('thresholds [−∞, 15, 32, 46, 60, 75] pick the highest stage reached', () {
      for (final (score, stage) in [
        (0.0, 0), (14.9, 0), (15.0, 1), (31.9, 1), (32.0, 2), (45.9, 2),
        (46.0, 3), (59.9, 3), (60.0, 4), (74.9, 4), (75.0, 5),
      ]) {
        // start at stage 0 and let the engine find where these values belong
        final r = rel(values: atScore(score), stageIdx: 0, romanticFrom: null);
        // hysteresis can only hold a stage *down*, never lift one
        expect(stageFor(r), stage, reason: 'score $score');
      }
    });

    test('stages belong to each relationship: a custom arc works the same way', () {
      final r = Relationship(
        id: 'm',
        characterId: 'morrow',
        personaId: 'wren',
        stages: const ['Visitor', 'Reader', 'Regular', 'Trusted Reader', 'Apprentice Archivist', 'Keeper of the Stacks'],
        values: atScore(50),
        stageIdx: 0,
      );
      final moved = r.copyWith(stageIdx: stageFor(r));
      expect(moved.stageName, 'Trusted Reader');
    });
  });

  group('stage hysteresis', () {
    test('a stage only drops once the score is 5 below its threshold', () {
      // standing at stage 3 (threshold 46)
      var r = rel(values: atScore(44), stageIdx: 3, romanticFrom: null);
      expect(stageFor(r), 3, reason: '44 is below 46 but not below 41');
      r = rel(values: atScore(41), stageIdx: 3, romanticFrom: null);
      expect(stageFor(r), 3, reason: 'exactly 5 below still holds');
      r = rel(values: atScore(40.9), stageIdx: 3, romanticFrom: null);
      expect(stageFor(r), 2, reason: 'clearly below: drops one stage');
    });

    test('rising is not delayed by hysteresis', () {
      final r = rel(values: atScore(46), stageIdx: 2, romanticFrom: null);
      expect(stageFor(r), 3);
    });

    test('one bad moment does not undo a stage', () {
      var run = Run(rel(values: const Values(trust: 60, affection: 30, tension: 0), stageIdx: 3, romanticFrom: null));
      // score = 36+12 = 48 → stage 3. A conflict adds tension 4 → score 46.8, still 3.
      run.say('You are a liar and a coward, honestly');
      expect(run.r.stageIdx, 3);
    });

    test('the engine logs a milestone when the stage moves', () {
      final run = Run(rel(values: const Values(trust: 24, affection: 0), stageIdx: 0, romanticFrom: null));
      // score 14.4 → stage 0; a promise (+4 trust) → 16.8 → stage 1
      final o = run.say('I promise I will keep your secret');
      expect(o, isA<Applied>());
      expect(run.r.stageIdx, 1);
      final entry = (o as Applied).stageEvent!;
      expect(entry.category, TimelineKind.milestone);
      expect(entry.title, 'Stage: ${run.r.stages[1]}');
      expect(entry.stageBefore, 0);
      expect(entry.stageAfter, 1);
      expect(run.r.events.first.id, entry.id, reason: 'stage entry sits on top');
    });
  });

  group('stage lock', () {
    test('a locked stage never moves automatically', () {
      final r = rel(values: atScore(80), stageIdx: 1, locked: true, romanticFrom: null);
      expect(stageFor(r), 1);
      final lowered = rel(values: atScore(0), stageIdx: 4, locked: true, romanticFrom: null);
      expect(stageFor(lowered), 4);
    });

    test('values still change while the stage is locked', () {
      final run = Run(rel(values: atScore(14), stageIdx: 0, locked: true, romanticFrom: null));
      run.say('I promise I will keep your secret');
      expect(run.r.values.trust, closeTo(atScore(14).trust + 4, 1e-9));
      expect(run.r.stageIdx, 0);
      expect(run.r.events.where((e) => e.title.startsWith('Stage:')), isEmpty);
    });

    test('saveStages can lock the stage you set yourself', () {
      final r = engine.saveStages(rel(), const [], 3, true, now: t0);
      expect(r.stageIdx, 3);
      expect(r.stageLocked, isTrue);
      expect(r.events.first.title, 'Stage set to ${r.stages[3]}');
      expect(r.events.first.why, contains('locked'));
    });

    test('the lock shows up in what the AI is told', () {
      expect(promptBlock(rel(locked: true)), contains('(locked by user)'));
    });
  });

  group('romance gate', () {
    test('the romantic stages need attraction ≥ 35 on a type that allows romance', () {
      // score 62 would be stage 4 (Unspoken Feelings, romanticFrom 4)
      final v = const Values(trust: 80, affection: 35, attraction: 10, tension: 0);
      expect(stageScore(v), closeTo(62, 1e-9));
      expect(stageFor(rel(values: v, stageIdx: 3)), 3, reason: 'attraction 10 < 35');
      expect(stageFor(rel(values: v.copyWith(attraction: 34), stageIdx: 3)), 3);
      expect(stageFor(rel(values: v.copyWith(attraction: 35), stageIdx: 3)), 4);
    });

    test('a platonic or family relationship never reaches the romantic stages', () {
      final v = const Values(trust: 100, affection: 100, attraction: 90, tension: 0);
      for (final t in [RelationType.platonic, RelationType.familial, RelationType.rivalrous, RelationType.other]) {
        expect(stageFor(rel(values: v, type: t, stageIdx: 3)), 3, reason: t.label);
      }
      expect(stageFor(rel(values: v, type: RelationType.romantic, stageIdx: 3)), 5);
    });

    test('switching to Platonic caps the stage at once, history is kept', () {
      var r = rel(
          values: const Values(trust: 90, affection: 70, attraction: 50, tension: 0),
          type: RelationType.romantic,
          stageIdx: 4);
      final before = r.events.length;
      r = engine.setType(r, RelationType.platonic);
      expect(r.stageIdx, 3, reason: 'hysteresis must not override the gate');
      expect(r.values.attraction, 50, reason: 'history is kept');
      expect(r.events.length, before);
      expect(promptBlock(r), contains('attraction n/a'));
      expect(promptBlock(r), contains('no romance'));
    });

    test('a romantic gesture only counts when the type allows romance', () {
      final blocked = Run(rel(type: RelationType.platonic));
      final o = blocked.say('You look beautiful tonight, truly');
      expect(o, isA<Ignored>());
      expect((o as Ignored).reason, IgnoreReason.romanceOff);
      expect(o.counted, isTrue);
      expect(blocked.r.values.attraction, 0);

      final allowed = Run(rel(type: RelationType.undecided));
      allowed.say('You look beautiful tonight, truly');
      expect(allowed.event.deltas, {RelValue.attraction: 2});
      expect(allowed.r.values.attraction, 2);
    });

    test('affection never converts into attraction', () {
      final run = Run(rel(values: const Values(trust: 30, affection: 20, attraction: 0)));
      run.say('Thank you so much for that');
      expect(run.r.values.affection, 21);
      expect(run.r.values.attraction, 0);
    });
  });

  group('cooldown', () {
    test('each kind counts at most once per 6 user turns', () {
      final run = Run(rel());
      expect(run.say('I promise I will keep your secret'), isA<Applied>()); // turn 1
      run.quiet(3); // turns 2–4
      final again = run.say('You have my word, I will not tell'); // turn 5
      expect(again, isA<Ignored>());
      expect((again as Ignored).reason, IgnoreReason.cooldown);
      expect(run.r.values.trust, 34, reason: 'only the first promise counted');
    });

    test('it counts again from the 6th turn on', () {
      final run = Run(rel());
      run.say('I promise I will keep your secret'); // turn 1
      run.quiet(4); // turns 2–5
      final again = run.say('You have my word, I will not tell'); // turn 6: 6 − 1 = 5 < 6 → still cooling
      expect(again, isA<Ignored>());
      run.quiet(0);
      final later = run.say('I swear I will not tell anyone this'); // turn 7: 6 turns after turn 1
      expect(later, isA<Applied>());
    });

    test('appreciation: refused inside 10 turns, counted at 10', () {
      final run = Run(rel());
      run.say('Thank you so much for that'); // turn 1
      run.quiet(8); // turns 2–9
      final inside = run.say('That was kind of you, really'); // turn 10: 9 turns later
      expect(inside, isA<Ignored>());
      final outside = run.say("I'm glad you are here with me"); // turn 11: 10 turns later
      expect(outside, isA<Applied>());
    });

    test('different kinds do not share a cooldown', () {
      final run = Run(rel());
      expect(run.say('I promise I will keep your secret'), isA<Applied>());
      expect(run.say('Let me help you carry that lamp'), isA<Applied>());
    });

    test('a refused moment adds to the "small moments were not counted" tally', () {
      final run = Run(rel());
      run.say('I promise I will keep your secret');
      expect(run.r.ignored, 0);
      run.say('You have my word, I will not tell');
      expect(run.r.ignored, 1);
    });

    test('proposals share the cooldown with user events', () {
      final run = Run(rel());
      run.say('I promise I will keep your secret');
      final p = engine.processModelProposal(
        run.r,
        ModelProposal(
          kindId: 'promise_made',
          evidence: 'I will keep it safe',
          reason: 'She promised to guard the key',
          messageId: 'ai1',
          recentMessages: const ['I will keep it safe, I swear'],
          now: t0,
        ),
        characterFirst: 'Vesper',
      );
      expect(p, isA<Ignored>());
      expect((p as Ignored).reason, IgnoreReason.cooldown);
    });
  });

  group('diminishing returns', () {
    test('× 1/(1 + 0.5·n) for each earlier time it counted in the last 30 turns', () {
      final run = Run(rel());
      run.say('I promise I will keep your secret');
      expect(run.event.deltas[RelValue.trust], 4); // n = 0
      run.quiet(6);
      run.say('You have my word, I will not tell');
      expect(run.event.deltas[RelValue.trust], 2.5, reason: '4 × 1/1.5 = 2.67 → 2.5');
      expect(run.event.multipliers['repeat'], closeTo(1 / 1.5, 1e-9));
      run.quiet(6);
      run.say('I swear I will not tell anyone this');
      expect(run.event.deltas[RelValue.trust], 2, reason: '4 × 1/2');
    });

    test('moments older than 30 turns no longer count against it', () {
      final run = Run(rel());
      run.say('I promise I will keep your secret');
      run.quiet(31);
      run.say('You have my word, I will not tell');
      expect(run.event.deltas[RelValue.trust], 4, reason: 'n = 0 again');
      expect(run.event.multipliers.containsKey('repeat'), isFalse);
    });

    test('the timeline explains it', () {
      final run = Run(rel());
      run.say('I promise I will keep your secret');
      run.quiet(6);
      run.say('You have my word, I will not tell');
      expect(run.event.why, contains('A similar moment already counted, so this one weighs less.'));
    });
  });

  group('scene budget', () {
    test('at most 8 points in total per 10 turns; the last change is scaled to fit', () {
      final run = Run(rel(values: const Values(trust: 30, affection: 20)));
      run.say('I promise I will keep your secret'); // 4 points
      final o = run.say('I will save you from the water, grab my hand'); // rescue: 9 points, only 4 left
      expect(o, isA<Applied>());
      final total = run.event.deltas.values.fold<double>(0, (s, d) => s + d.abs());
      expect(total, lessThanOrEqualTo(4.0 + 1e-9));
      expect(run.event.multipliers['budget'], closeTo(4 / 9, 1e-9));
      expect(run.event.why, contains('Capped: this scene has already moved things a lot.'));
    });

    test('once the budget is used up, further moments are refused', () {
      final run = Run(rel());
      run.say('I promise I will keep your secret'); // 4
      run.say('I will save you from the water, grab my hand'); // ≈4 → 8 used
      final o = run.say('Let me help you carry that lamp now');
      expect(o, isA<Ignored>());
      expect((o as Ignored).reason, IgnoreReason.sceneBudget);
    });

    test('the budget comes back after 10 turns', () {
      final run = Run(rel());
      run.say('I promise I will keep your secret');
      run.say('I will save you from the water, grab my hand');
      run.quiet(9);
      expect(run.say('Let me help you carry that lamp now'), isA<Applied>());
    });

    test('big setbacks use the budget too', () {
      final run = Run(rel(values: const Values(trust: 60, affection: 40, tension: 0)));
      run.say('Just tell me what is in the letter now'); // boundary_crossed: −3 / +5 = 8 points
      expect(run.r.values.tension, 5);
      final o = run.say('You are a coward and a liar');
      expect(o, isA<Ignored>());
      expect((o as Ignored).reason, IgnoreReason.sceneBudget);
    });
  });

  group('daily cap', () {
    test('no value moves more than ±12 in a day', () {
      final run = Run(rel(values: const Values(trust: 20, affection: 20)));
      run.say('I promise I will keep your secret'); // trust +4
      run.quiet(10);
      run.say('Let me help you carry that lamp now'); // trust +3, affection +1
      run.quiet(10);
      run.say('Take your time, there is no pressure at all'); // trust +3
      run.quiet(10);
      expect(run.r.values.trust, 30, reason: '20 + 4 + 3 + 3');
      run.say('I will save you from the water, grab my hand'); // rescue +6 trust: only +2 left today
      expect(run.event.deltas[RelValue.trust], 2);
      expect(run.event.multipliers.containsKey('daily'), isTrue);
      expect(run.r.values.trust, 32);
      expect(run.event.why, contains('Capped: this value has moved a lot today.'));
    });

    test('a new day starts a fresh allowance', () {
      final run = Run(rel(values: const Values(trust: 20, affection: 20)));
      run.say('I promise I will keep your secret');
      run.quiet(10);
      run.say('Let me help you carry that lamp now');
      run.quiet(10);
      run.say('Take your time, there is no pressure at all');
      run.quiet(10);
      run.say('I will save you from the water, grab my hand', after: const Duration(days: 1));
      expect(run.event.deltas[RelValue.trust], 5.5, reason: 'the scene budget (8) still scales 6 → 5.33');
      expect(run.event.multipliers.containsKey('daily'), isFalse);
    });
  });

  group('pacing', () {
    test('Slow burn: gains × 0.5, setbacks × 0.75, rounded to 0.5', () {
      final gain = Run(rel(pacing: RelPacing.slow));
      gain.say('I promise I will keep your secret');
      expect(gain.event.deltas[RelValue.trust], 2);
      expect(gain.event.multipliers['pacing'], 0.5);
      expect(gain.event.why, contains('Slow burn pacing: Trust +4 → +2.'));

      final loss = Run(rel(pacing: RelPacing.slow, values: const Values(trust: 50, affection: 30, tension: 0)));
      loss.say('Just tell me what is in the letter now');
      expect(loss.event.deltas[RelValue.trust], -2.5, reason: '−3 × 0.75 = −2.25 → −2.5');
      expect(loss.event.deltas[RelValue.tension], 4, reason: '5 × 0.75 = 3.75 → 4');
    });

    test('Balanced is 1 / 1', () {
      final run = Run(rel(pacing: RelPacing.balanced));
      run.say('I promise I will keep your secret');
      expect(run.event.deltas[RelValue.trust], 4);
      expect(run.event.multipliers.containsKey('pacing'), isFalse);
    });

    test('Fast: gains × 1.6, setbacks × 1.2', () {
      final run = Run(rel(pacing: RelPacing.fast));
      run.say('I promise I will keep your secret');
      expect(run.event.deltas[RelValue.trust], 6.5, reason: '4 × 1.6 = 6.4 → 6.5');
    });

    test('tiny changes that round to nothing are not counted', () {
      final run = Run(rel(pacing: RelPacing.slow));
      final o = run.say('Thank you so much for that'); // +1 × 0.5 = 0.5 → ok
      expect(o, isA<Applied>());
      expect(run.event.deltas[RelValue.affection], 0.5);
    });

    test('Manual pacing makes a suggestion instead of a change', () {
      final run = Run(rel(pacing: RelPacing.manual));
      final o = run.say('I promise I will keep your secret');
      expect(o, isA<Suggested>());
      expect(run.r.values.trust, 30, reason: 'nothing changed by itself');
      expect(run.r.pending, hasLength(1));
      expect(run.r.pending.single.deltas, {RelValue.trust: 4});
      expect((o as Suggested).note.text, 'Suggested change · review it');
      expect(o.note.entryId, isNull);
    });

    test('approving a suggestion applies it, stamped as approved by you', () {
      final run = Run(rel(pacing: RelPacing.manual));
      run.say('I promise I will keep your secret');
      final r = engine.acceptSuggestion(run.r, run.r.pending.single.id, now: t0);
      expect(r.values.trust, 34);
      expect(r.pending, isEmpty);
      expect(r.events.first.source, EventSource.approved);
      expect(r.events.first.why, endsWith('Approved by you (Manual pacing).'));
      expect(r.events.first.canUndo, isTrue);
    });

    test('dismissing a suggestion changes nothing but counts as a small moment', () {
      final run = Run(rel(pacing: RelPacing.manual));
      run.say('I promise I will keep your secret');
      final r = engine.dismissSuggestion(run.r, run.r.pending.single.id);
      expect(r.pending, isEmpty);
      expect(r.values.trust, 30);
      expect(r.ignored, 1);
    });

    test('a waiting suggestion still holds the cooldown', () {
      final run = Run(rel(pacing: RelPacing.manual));
      run.say('I promise I will keep your secret');
      final o = run.say('You have my word, I will not tell');
      expect(o, isA<Ignored>());
      expect(run.r.pending, hasLength(1));
    });
  });

  group('trivial filter', () {
    test('fewer than 4 words never counts', () {
      final run = Run(rel());
      final o = run.say('Thank you!');
      expect(o, isA<Ignored>());
      expect((o as Ignored).reason, IgnoreReason.trivial);
      expect(run.r.values.affection, 20);
    });

    test('out-of-character lines (( … )) never count', () {
      final run = Run(rel());
      final o = run.say('((thank you so much for that, really))');
      expect((o as Ignored).reason, IgnoreReason.trivial);
    });

    test('emoji-only messages never count', () {
      final run = Run(rel());
      final o = run.say('🙏🙏🙏🙏🙏 ❤️ ❤️');
      expect(o, isA<Ignored>());
    });

    test('a message already seen in the last 20 turns does not count twice', () {
      final run = Run(rel());
      run.say('Thank you so much for that'); // turn 1: counts
      run.quiet(10); // 2–11
      final o = run.say('Thank you so much for that!'); // turn 12: cooldown over, but the same text
      expect(o, isA<Ignored>());
      expect((o as Ignored).reason, IgnoreReason.trivial);
      run.quiet(20);
      expect(run.say('Thank you so much for that'), isA<Applied>(), reason: 'not seen for over 20 turns');
    });

    test('messages that match nothing are simply not moments', () {
      final run = Run(rel());
      final o = run.say('The tide keeps coming in tonight');
      expect((o as Ignored).reason, IgnoreReason.noMatch);
      expect(o.counted, isFalse);
      expect(run.r.ignored, 0);
      expect(run.r.turn, 1, reason: 'but the turn still counted');
    });
  });

  group('events from the model', () {
    ModelProposal prop({
      String kind = 'vulnerability_shared',
      String evidence = "I haven't shown that to anyone",
      List<String>? recent,
      String id = 'ai1',
    }) =>
        ModelProposal(
          kindId: kind,
          evidence: evidence,
          reason: 'Vesper showed the logbook',
          messageId: id,
          recentMessages: recent ?? ['*She turns the cup.* "I haven\'t shown that to anyone. Don\'t make me regret it."'],
          now: t0,
        );

    test('a proposal with evidence is validated and applied like any other event', () {
      final o = engine.processModelProposal(rel(pacing: RelPacing.slow), prop(), characterFirst: 'Vesper');
      expect(o, isA<Applied>());
      final e = (o as Applied).event;
      expect(e.source, EventSource.modelProposal);
      expect(e.title, 'Vesper showed the logbook');
      expect(e.deltas, {RelValue.trust: 1.5, RelValue.affection: 1});
      expect(e.evidence, "I haven't shown that to anyone");
      expect(e.why, contains('Vesper did something that counts'));
    });

    test('the evidence must quote one of the last 6 messages', () {
      final far = List.generate(8, (i) => i == 0 ? "I haven't shown that to anyone" : 'Line $i of the story');
      final out = engine.processModelProposal(rel(), prop(recent: far), characterFirst: 'Vesper');
      expect((out as Ignored).reason, IgnoreReason.noEvidence);
      final near = List.generate(8, (i) => i == 3 ? "I haven't shown that to anyone" : 'Line $i of the story');
      expect(engine.processModelProposal(rel(), prop(recent: near), characterFirst: 'Vesper'), isA<Applied>());
    });

    test('missing or made-up evidence is discarded', () {
      expect((engine.processModelProposal(rel(), prop(evidence: ''), characterFirst: 'V') as Ignored).reason,
          IgnoreReason.noEvidence);
      expect(
          (engine.processModelProposal(rel(), prop(evidence: 'I love you forever'), characterFirst: 'V') as Ignored)
              .reason,
          IgnoreReason.noEvidence);
    });

    test('a kind that is not in the catalogue is discarded', () {
      final o = engine.processModelProposal(rel(), prop(kind: 'grant_wish'), characterFirst: 'V');
      expect((o as Ignored).reason, IgnoreReason.unknownKind);
    });

    test('the same reply never counts twice (unique on message + kind)', () {
      final first = engine.processModelProposal(rel(), prop(), characterFirst: 'V');
      final again = engine.processModelProposal(first.relationship, prop(), characterFirst: 'V');
      expect((again as Ignored).reason, IgnoreReason.duplicate);
      expect(again.relationship.values, first.relationship.values);
    });

    test('a proposal does not advance the user turn', () {
      final r = rel().copyWith(turn: 7);
      final o = engine.processModelProposal(r, prop(), characterFirst: 'V');
      expect(o.relationship.turn, 7);
    });
  });

  group('locked facts', () {
    test('an event that contradicts a locked fact (by tag) is rejected', () {
      final facts = [const Fact(id: 'f', text: 'You are siblings.', tags: ['family'])];
      final run = Run(rel(facts: facts));
      final o = run.say('You look beautiful tonight, truly');
      expect((o as Ignored).reason, IgnoreReason.contradictsFact);
    });

    test('an unlocked fact is only a note', () {
      final facts = [const Fact(id: 'f', text: 'You are siblings.', locked: false, tags: ['family'])];
      final run = Run(rel(facts: facts));
      expect(run.say('You look beautiful tonight, truly'), isA<Applied>());
    });

    test('promise_broken contradicts "never breaks promises"; betrayal contradicts "loyal"', () {
      final facts = [
        const Fact(id: 'a', text: 'She never breaks a promise.', tags: ['keeps-promises']),
        const Fact(id: 'b', text: 'He is loyal to the end.', tags: ['loyal']),
      ];
      expect(
          (engine.processUserMessage(rel(facts: facts),
                      UserTurn(messageId: 'x', text: 'I broke my promise to you, sorry', now: t0))
                  as Ignored)
              .reason,
          IgnoreReason.contradictsFact);
      final o = engine.processModelProposal(
        rel(facts: facts),
        ModelProposal(
            kindId: 'betrayal', evidence: 'I sold the map', reason: 'x', messageId: 'a',
            recentMessages: const ['I sold the map'], now: t0),
        characterFirst: 'V',
      );
      expect((o as Ignored).reason, IgnoreReason.contradictsFact);
    });

    test('facts get tags from what they say', () {
      expect(RelationshipEngine.inferFactTags('You are siblings.'), ['family']);
      expect(RelationshipEngine.inferFactTags('You are not related to Vesper'), isEmpty);
      expect(RelationshipEngine.inferFactTags('We are just friends'), ['platonic-only']);
      expect(RelationshipEngine.inferFactTags('She never breaks promises'), ['keeps-promises']);
      expect(RelationshipEngine.inferFactTags('He would never betray you'), ['loyal']);
      expect(RelationshipEngine.inferFactTags('It rained'), isEmpty);
    });

    test('facts can be added, locked, unlocked and removed', () {
      var r = engine.addFact(rel(), '  The bell is cursed. ');
      expect(r.facts.single.text, 'The bell is cursed.');
      expect(r.facts.single.locked, isTrue);
      r = engine.setFactLocked(r, r.facts.single.id, false);
      expect(r.facts.single.locked, isFalse);
      r = engine.removeFact(r, r.facts.single.id);
      expect(r.facts, isEmpty);
      expect(engine.addFact(rel(), '   ').facts, isEmpty);
    });
  });

  group('event rules', () {
    test('apology / reconciliation only counts when tension is above 10', () {
      final calm = Run(rel(values: const Values(trust: 30, affection: 20, tension: 5)));
      final o = calm.say('I am sorry, I was wrong about that');
      expect((o as Ignored).reason, IgnoreReason.tensionTooLow);

      final tense = Run(rel(values: const Values(trust: 30, affection: 20, tension: 14)));
      tense.say('I am sorry, I was wrong about that');
      expect(tense.event.category, TimelineKind.reconcile);
      expect(tense.event.deltas, {RelValue.tension: -4, RelValue.trust: 2});
      expect(tense.r.values.tension, 10);
    });

    test('promise_kept needs an earlier promise_made', () {
      final none = Run(rel());
      expect((none.say('I kept my promise, as promised') as Ignored).reason, IgnoreReason.earlierMissing);

      final run = Run(rel());
      run.say('I promise I will keep your secret');
      run.quiet(10);
      run.say('I kept my promise, as promised to you');
      expect(run.event.kindId, 'promise_kept');
      expect(run.event.deltas[RelValue.trust], 6);
    });

    test('values stay between 0 and 100', () {
      final low = Run(rel(values: const Values(trust: 1, affection: 0, tension: 99)));
      low.say('You are a liar and a coward, truly');
      expect(low.r.values.tension, 100);
      expect(low.r.values.trust, 1);
      final r = engine.applyCorrection(rel(), const Values(trust: 150, affection: -5), now: t0);
      expect(r.values.trust, 100);
      expect(r.values.affection, 0);
    });

    test('the catalogue matches RELATIONSHIP_ENGINE.md', () {
      final c = eventCatalogue;
      expect(c['promise_made']!.deltas, {RelValue.trust: 4});
      expect(c['promise_kept']!.deltas, {RelValue.trust: 6});
      expect(c['promise_broken']!.deltas, {RelValue.trust: -8, RelValue.tension: 6});
      expect(c['help_offered']!.deltas, {RelValue.trust: 3, RelValue.affection: 1});
      expect(c['rescue']!.deltas, {RelValue.trust: 6, RelValue.affection: 3});
      expect(c['boundary_respected']!.deltas, {RelValue.trust: 3, RelValue.tension: -1});
      expect(c['boundary_crossed']!.deltas, {RelValue.trust: -3, RelValue.tension: 5});
      expect(c['vulnerability_shared']!.deltas, {RelValue.trust: 3, RelValue.affection: 2});
      expect(c['conflict']!.deltas, {RelValue.tension: 4});
      expect(c['apology']!.deltas, {RelValue.tension: -4, RelValue.trust: 2});
      expect(c['betrayal']!.deltas, {RelValue.trust: -12, RelValue.affection: -4, RelValue.tension: 10});
      expect(c['appreciation']!.deltas, {RelValue.affection: 1});
      expect(c['appreciation']!.cooldown, 10);
      expect(c['romantic_gesture']!.deltas, {RelValue.attraction: 2});
      expect(c.values.where((k) => k.id != 'appreciation').every((k) => k.cooldown == 6), isTrue);
    });
  });

  group('undo', () {
    test('reverses the values, strikes the original through and never deletes it', () {
      final run = Run(rel());
      run.say('I promise I will keep your secret');
      final id = run.event.id;
      final before = run.r.events.length;

      final r = engine.undo(run.r, id, now: t0);
      expect(r.values.trust, 30);
      expect(r.events.length, before + 1, reason: 'append-only');
      final original = r.events.firstWhere((e) => e.id == id);
      expect(original.isUndone, isTrue);
      expect(original.undoneBy, r.events.first.id);
      final reversing = r.events.first;
      expect(reversing.undoOf, id);
      expect(reversing.category, TimelineKind.correction);
      expect(reversing.title, 'Undid: I made a promise'.replaceFirst('I made', 'You made'));
      expect(reversing.deltas, {RelValue.trust: -4});
      expect(reversing.why, contains('You reversed this change.'));
    });

    test('frees the cooldown and the budget again', () {
      final run = Run(rel());
      run.say('I promise I will keep your secret');
      final id = run.event.id;
      run.r = engine.undo(run.r, id, now: t0);
      final o = run.say('You have my word, I will not tell');
      expect(o, isA<Applied>(), reason: 'the undone promise no longer counts');
      expect(run.event.deltas[RelValue.trust], 4, reason: 'and it no longer weighs it down');
    });

    test('can only be done once, and not for milestones or reversing events', () {
      final run = Run(rel());
      run.say('I promise I will keep your secret');
      final id = run.event.id;
      final once = engine.undo(run.r, id, now: t0);
      final twice = engine.undo(once, id, now: t0);
      expect(twice.events.length, once.events.length);
      expect(twice.values, once.values);
      expect(engine.undo(once, once.events.first.id, now: t0).events.length, once.events.length);
      expect(engine.undo(once, 'nope', now: t0), same(once));
    });

    test('moves the stage back with hysteresis, and says so', () {
      final run = Run(rel(values: const Values(trust: 24, affection: 0), stageIdx: 0, romanticFrom: null));
      run.say('I promise I will keep your secret'); // → stage 1
      expect(run.r.stageIdx, 1);
      final r = engine.undo(run.r, run.event.id, now: t0);
      expect(r.values.trust, closeTo(24, 1e-9)); // score 14.4 → stage 0
      expect(r.stageIdx, 1, reason: 'hysteresis: 14.4 is not 5 below 15');
    });

    test('undoing a correction restores the old values', () {
      var r = engine.applyCorrection(rel(), const Values(trust: 60, affection: 20), now: t0);
      expect(r.values.trust, 60);
      final correction = r.events.firstWhere((e) => e.kindId == 'correction');
      r = engine.undo(r, correction.id, now: t0);
      expect(r.values.trust, 30);
    });
  });

  group('corrections', () {
    test('your correction becomes the new baseline and is logged', () {
      final r = engine.applyCorrection(rel(), const Values(trust: 50, affection: 20, attraction: 0, tension: 10),
          reason: 'We made up off-screen', now: t0);
      expect(r.values.trust, 50);
      expect(r.values.tension, 10);
      final e = r.events.firstWhere((e) => e.kindId == 'correction');
      expect(e.title, 'We made up off-screen');
      expect(e.category, TimelineKind.correction);
      expect(e.source, EventSource.user);
      expect(e.deltas, {RelValue.trust: 20, RelValue.tension: 10});
      expect(e.canUndo, isTrue);
      expect(e.why, contains('new baseline'));
    });

    test('no change, no entry; a blank reason says "Adjusted by you"', () {
      final r = rel();
      expect(engine.applyCorrection(r, r.values, now: t0), same(r));
      final c = engine.applyCorrection(r, const Values(trust: 40, affection: 20), reason: '  ', now: t0);
      expect(c.events.firstWhere((e) => e.kindId == 'correction').title, 'Adjusted by you');
    });

    test('a correction can move the stage and logs it', () {
      final r = engine.applyCorrection(rel(), const Values(trust: 60, affection: 40), now: t0);
      expect(r.stageIdx, greaterThan(1));
      expect(r.events.first.title, startsWith('Stage:'));
      expect(r.events.first.source, EventSource.user);
      expect(r.events[1].kindId, 'correction');
    });
  });

  group('idempotence and edits', () {
    test('the same message never counts twice', () {
      final r = rel();
      final u = UserTurn(messageId: 'm1', text: 'I promise I will keep your secret', now: t0);
      final first = engine.processUserMessage(r, u);
      final again = engine.processUserMessage(first.relationship, u);
      expect((again as Ignored).reason, IgnoreReason.duplicate);
      expect(again.relationship.values, first.relationship.values);
      expect(again.relationship.turn, first.relationship.turn, reason: 'a replay is not a new turn');
    });

    test('an edited message is evaluated again and its old effect replaced', () {
      final run = Run(rel());
      run.say('I promise I will keep your secret');
      expect(run.r.values.trust, 34);
      final turn = run.r.turn;

      final edited = engine.reevaluateEdited(
        run.r,
        UserTurn(messageId: 'm1', text: 'Thank you so much for that', now: t0),
      );
      expect(edited, isA<Applied>());
      final r = edited.relationship;
      expect(r.values.trust, 30, reason: 'the promise is gone');
      expect(r.values.affection, 21, reason: 'the thanks counts instead');
      expect(r.turn, turn, reason: 'an edit is not a new turn');
      expect(r.events.firstWhere((e) => e.title == 'You made a promise').isUndone, isTrue);
    });

    test('editing a message so it matches nothing just removes the effect', () {
      final run = Run(rel());
      run.say('I promise I will keep your secret');
      final o = engine.reevaluateEdited(run.r, UserTurn(messageId: 'm1', text: 'Never mind that, really', now: t0));
      expect(o.relationship.values.trust, 30);
      expect(o, isA<Ignored>());
    });

    test('a waiting suggestion is withdrawn when its message is edited', () {
      final run = Run(rel(pacing: RelPacing.manual));
      run.say('I promise I will keep your secret');
      final o = engine.reevaluateEdited(run.r, UserTurn(messageId: 'm1', text: 'Never mind that, really', now: t0));
      expect(o.relationship.pending, isEmpty);
    });
  });

  group('deleted chats', () {
    test('events stay in the timeline, marked as from a deleted chat', () {
      final run = Run(rel());
      run.r = run.r.copyWith();
      final r = engine.markChatDeleted(
          engine.processUserMessage(
              run.r,
              UserTurn(messageId: 'm1', text: 'I promise I will keep your secret', now: t0, conversationId: 'c9'),
            ).relationship,
          'c9');
      expect(r.events.first.fromDeletedChat, isTrue);
      expect(r.events, isNotEmpty);
    });
  });

  group('type, presets and stages', () {
    test('presets replace the stage names and the romantic stage', () {
      var r = engine.applyPreset(rel(), presetById('friendship'));
      expect(r.stages[3], 'Friends');
      expect(r.romanticFrom, isNull);
      r = engine.applyPreset(r, presetById('romance'));
      expect(r.romanticFrom, 4);
      expect(stagePresets.map((p) => p.label), ['Romance arc', 'Friendship', 'Rivalry', 'Family']);
      for (final p in stagePresets) {
        expect(p.stages, hasLength(6));
      }
    });

    test('saveStages keeps old names for blank ones and logs a stage you set', () {
      final r = engine.saveStages(rel(), ['', 'Wary', '', '', '', ''], 1, false, now: t0);
      expect(r.stages[0], 'Strangers');
      expect(r.stages[1], 'Wary');
      expect(r.events, isEmpty, reason: 'same stage: nothing to log');
      final moved = engine.saveStages(r, const [], 2, false, now: t0);
      expect(moved.events.first.title, 'Stage set to ${moved.stages[2]}');
      expect(moved.events.first.why, contains('may move it again'));
    });

    test('pacing and type are plain settings', () {
      expect(engine.setPacing(rel(), RelPacing.fast).pacing, RelPacing.fast);
      expect(engine.setType(rel(), RelationType.familial).type, RelationType.familial);
    });
  });

  group('words, behaviour lines and what the AI is told', () {
    test('words come from deterministic bands', () {
      expect(wordFor(RelValue.trust, 19.9), 'Wary');
      expect(wordFor(RelValue.trust, 20), 'Cautious');
      expect(wordFor(RelValue.trust, 79.9), 'Deep');
      expect(wordFor(RelValue.trust, 80), 'Unshakeable');
      expect(wordFor(RelValue.affection, 22), 'Polite warmth');
      expect(wordFor(RelValue.attraction, 5), 'None shown');
      expect(wordFor(RelValue.tension, 14), 'At ease');
      expect(wordFor(RelValue.tension, 15), 'Mild');
      expect(wordFor(RelValue.tension, 60), 'Volatile');
    });

    test('behaviour lines follow the bands (four lines, always)', () {
      final calm = behaviorLines(rel(values: const Values(trust: 10, affection: 10, tension: 5)));
      expect(calm, hasLength(4));
      expect(calm[0], 'Keeps answers short and guards anything personal.');
      expect(calm[1], 'Polite, a little cool.');
      expect(calm[2], 'At ease in your company.');
      expect(calm[3], 'Shows no romantic interest; fondness stays platonic for now.');
      final warm = behaviorLines(rel(values: const Values(trust: 80, affection: 60, attraction: 70, tension: 50)));
      expect(warm[0], 'Trusts you with secrets — and with their safety.');
      expect(warm[1], 'Openly glad to see you; teases you and checks on you.');
      expect(warm[2], 'On edge: likely to argue, test you or pull away.');
      expect(warm[3], 'Romantic feelings are present and may be acknowledged.');
      expect(behaviorLines(rel(type: RelationType.platonic))[3],
          'Romance is off the table — affection reads as friendship, family or respect.');
    });

    test('the prompt block for Vesper matches the contract', () {
      final v = seedRelationship(characterId: 'vesper', personaId: 'wren', now: t0);
      final block = promptBlock(v).split('\n');
      expect(block[0], '[relationship — set by the app, read-only]');
      expect(block[1], 'stage: Wary Acquaintances');
      expect(block[2], 'type: Let the story decide — do not assume romance');
      expect(block[3],
          'trust 32 (cautious), affection 22 (polite warmth), attraction 6, tension 14 (at ease)');
      expect(block[4], 'pacing: slow burn — change openness gradually; no sudden confessions');
      expect(block[5], 'play it like this:');
      expect(block.sublist(6, 10).every((l) => l.startsWith('- ')), isTrue);
      expect(block.contains('never contradict:'), isTrue);
      expect(block, contains('- Vesper has never told anyone about the bell.'));
      expect(block, contains('- You are not related to Vesper, whatever the letters say.'));
      expect(block, contains('latest turning point: You gave your word about the letters'));
      expect(block.last,
          'you may propose ONE relationship_event {kind, reason}; the app decides whether it counts.');
    });

    test('Jun (platonic) is told romance is off and attraction is n/a', () {
      final text = promptBlock(seedRelationship(characterId: 'jun', personaId: 'wren', now: t0));
      expect(text, contains('type: Platonic — no romance'));
      expect(text, contains('attraction n/a'));
    });

    test('"latest turning point" ignores corrections and undone moments', () {
      var r = seedRelationship(characterId: 'vesper', personaId: 'wren', now: t0);
      r = engine.applyCorrection(r, const Values(trust: 40, affection: 22, attraction: 6, tension: 14), now: t0);
      expect(promptBlock(r), contains('latest turning point: You gave your word about the letters'));
      r = engine.undo(r, 'e5', now: t0);
      expect(promptBlock(r), contains('latest turning point: Stage: Wary Acquaintances'.replaceFirst('Stage: Wary Acquaintances', 'Stage reached: Wary Acquaintances')));
    });

    test('"Next:" hints', () {
      expect(nextHint(rel(locked: true)), contains('This stage is locked'));
      expect(nextHint(rel(stageIdx: 5)), contains('The last stage on this arc'));
      final far = nextHint(rel(values: atScore(16), stageIdx: 1));
      expect(far, startsWith('Next: Reluctant Allies — still a long way off.'));
      expect(far, endsWith('More trust would help most.'));
      expect(nextHint(rel(values: atScore(30), stageIdx: 1)), contains('getting closer'));
      expect(nextHint(rel(values: const Values(trust: 30, affection: 20, tension: 30), stageIdx: 1)),
          endsWith('Easing the tension would help most.'));
      final gated = nextHint(rel(
          values: const Values(trust: 80, affection: 35, attraction: 5), stageIdx: 3));
      expect(gated, contains('only if attraction grows in the story'));
    });

    test('type hints', () {
      expect(typeHint(RelationType.platonic), startsWith('Romance is off.'));
      expect(typeHint(RelationType.undecided), contains('High affection never means romance'));
      expect(typeHint(RelationType.romantic), startsWith('Romance is allowed.'));
    });
  });

  group('notes under a message: words, never numbers', () {
    RelationshipNote note(Map<RelValue, double> d, TimelineKind k) => RelationshipEngine.noteFor(d, k);

    test('chat wording', () {
      expect(note({RelValue.trust: 1.5}, TimelineKind.shift).text, 'Trust grew a little');
      expect(note({RelValue.trust: 4}, TimelineKind.shift).text, 'Trust grew');
      expect(note({RelValue.trust: -2.5}, TimelineKind.setback).text, 'Trust slipped');
      expect(note({RelValue.tension: 5}, TimelineKind.setback).text, 'Tension rose');
      expect(note({RelValue.tension: -2}, TimelineKind.reconcile).text, 'Tension eased');
      expect(note({RelValue.affection: 0.5}, TimelineKind.shift).text, 'Affection grew a little');
      expect(note({RelValue.attraction: 2}, TimelineKind.shift).text, 'Attraction grew');
    });

    test('story wording', () {
      expect(note({RelValue.trust: 2}, TimelineKind.shift).story, 'Something shifted between you.');
      expect(note({RelValue.trust: -2}, TimelineKind.setback).story, 'A distance opened between you.');
      expect(note({RelValue.tension: -2}, TimelineKind.reconcile).story, 'Something mended, a little.');
    });

    test('no digits in any note', () {
      for (final k in TimelineKind.values) {
        final n = note({RelValue.trust: 7.5, RelValue.tension: -3}, k);
        expect(RegExp(r'\d').hasMatch('${n.text} ${n.story}'), isFalse);
      }
    });

    test('an applied event hands back a note that points at its timeline entry', () {
      final run = Run(rel());
      final o = run.say('I promise I will keep your secret') as Applied;
      expect(o.note.entryId, o.event.id);
      expect(o.note.text, 'Trust grew');
    });
  });

  group('helpers', () {
    test('signed() uses a real minus and drops .0', () {
      expect(signed(4), '+4');
      expect(signed(-2.5), '−2.5');
      expect(signed(1.5), '+1.5');
    });

    test('dayLabel', () {
      final now = DateTime(2026, 10, 17, 12);
      expect(dayLabel(now.subtract(const Duration(seconds: 10)), now), 'Just now');
      expect(dayLabel(now.subtract(const Duration(hours: 2)), now), 'Today');
      expect(dayLabel(now.subtract(const Duration(days: 1)), now), 'Yesterday');
      expect(dayLabel(now.subtract(const Duration(days: 4)), now), 'Tue');
      expect(dayLabel(now.subtract(const Duration(days: 15)), now), 'Oct 2');
    });

    test('classifier picks at most one kind, in order', () {
      expect(classifyUserText('I promise I will help you'), 'promise_made');
      expect(classifyUserText('The tide is coming in'), isNull);
      expect(classifyUserText('I kept my promise to you'), 'promise_kept');
      expect(classifyUserText('Thank you for the tea'), 'appreciation');
    });
  });

  group('seeds from the prototype', () {
    test('Vesper starts as Wary Acquaintances with the journey-G entry', () {
      final v = seedRelationship(characterId: 'vesper', personaId: 'wren', now: t0);
      expect(v.stageName, 'Wary Acquaintances');
      expect(v.values, const Values(trust: 31.5, affection: 22, attraction: 6, tension: 14));
      expect(v.type, RelationType.undecided);
      expect(v.pacing, RelPacing.slow);
      expect(v.romanticFrom, 4);
      expect(v.events.map((e) => e.id), ['e5', 'e4', 'e3', 'e2', 'e1']);
      expect(v.events.first.canUndo, isTrue);
      expect(v.facts, hasLength(2));
      expect(v.ignored, 2);
      expect(stageFor(v), 1, reason: 'the seed agrees with the stage maths');
    });

    test('every seed agrees with the stage maths', () {
      for (final id in ['vesper', 'jun', 'morrow', 'iselde', 'someone-new']) {
        final r = seedRelationship(characterId: id, personaId: 'wren', now: t0);
        expect(stageFor(r), r.stageIdx, reason: id);
        expect(r.stages, hasLength(6), reason: id);
      }
    });

    test('Jun is platonic, balanced, friendship stages; Morrow has its own arc', () {
      final j = seedRelationship(characterId: 'jun', personaId: 'wren', now: t0);
      expect((j.type, j.pacing, j.stageName), (RelationType.platonic, RelPacing.balanced, 'Allies'));
      final m = seedRelationship(characterId: 'morrow', personaId: 'wren', now: t0);
      expect(m.stages.last, 'Keeper of the Stacks');
      expect(m.stageName, 'Reader');
    });

    test('new characters get a gentle friendship arc', () {
      final n = seedRelationship(characterId: 'zed', personaId: 'wren', now: t0);
      expect(n.values, const Values());
      expect(n.stageName, 'Acquaintances');
      expect(n.events, isEmpty);
    });
  });
}
