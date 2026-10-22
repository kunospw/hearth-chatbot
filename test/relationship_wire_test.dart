import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hearth/core/backend/backend_api.dart';
import 'package:hearth/data/mock/mock_scenario.dart';
import 'package:hearth/features/characters/domain/character.dart';
import 'package:hearth/features/chat/data/reply_streaming_service.dart';
import 'package:hearth/features/chat/data/server_reply_service.dart';
import 'package:hearth/features/relationship/data/relationship_json.dart';
import 'package:hearth/features/relationship/data/server_relationship_backend.dart';
import 'package:hearth/features/relationship/domain/relationship_models.dart';

import 'support/fake_backend.dart';

Map<String, dynamic> fixture() =>
    jsonDecode(File('supabase/tests/golden/snapshot.json').readAsStringSync()) as Map<String, dynamic>;

const _char = Character(
  id: 'c-1',
  name: 'Vesper Hale',
  first: 'Vesper',
  initial: 'V',
  tile: Color(0xFF24383C),
  ink: Color(0xFFBFD9D6),
  short: '',
);

ReplyRequest request({
  bool stream = true,
  void Function(ServerTurnInfo)? onInfo,
  String? userMessageId = 'm-user',
  String? replaceMessageId,
  int altIndex = 0,
}) =>
    ReplyRequest(
      character: _char,
      history: const [],
      modelId: 'ember',
      stream: stream,
      conversationId: 'cv-1',
      personaId: 'p-1',
      userMessageId: userMessageId,
      replaceMessageId: replaceMessageId,
      aiMessageId: 'm-ai',
      altIndex: altIndex,
      settings: const ReplySettings(length: 'long', style: 'literary', temperature: 0.7, maxTokens: 900),
      onServerInfo: onInfo,
    );

Stream<SseEvent> events(List<(String, Map<String, dynamic>)> list) =>
    Stream.fromIterable([for (final e in list) SseEvent(e.$1, e.$2)]);

void main() {
  group('the snapshot the server sends', () {
    test('is read into the app’s relationship model', () {
      final r = relationshipFromJson(fixture());
      expect(r.id, 'rel-1');
      expect(r.characterId, 'char-1');
      expect(r.startingPoint, StartingPoint.strangers);
      expect(r.type, RelationType.undecided);
      expect(r.pacing, RelPacing.manual);
      expect(r.values.trust, 24);
      expect(r.version, 7);
      expect(r.stages, hasLength(6));
      expect(r.stageName, isNotEmpty);
      expect(r.facts.single.tags, ['family']);
      expect(r.facts.single.locked, isTrue);
      expect(r.pending, hasLength(1));
      expect(r.pending.single.kindId, 'help_offered');
      expect(r.pending.single.deltas[RelValue.trust], 3);
      expect(r.pending.single.source, EventSource.engine);

      final approved = r.events.firstWhere((e) => e.source == EventSource.approved);
      expect(approved.kindId, 'promise_made');
      expect(approved.category, TimelineKind.shift);
      expect(approved.deltas[RelValue.trust], 4);
      expect(approved.canUndo, isTrue);
      expect(approved.at.isUtc || approved.at.isBefore(DateTime(2100)), isTrue);
    });

    test('an unknown value falls back instead of breaking the screen', () {
      final j = fixture();
      j['type'] = 'something-new';
      j['pacing'] = 'warp';
      j['startingPoint'] = 'pen-pals';
      (j['events'] as List).first['category'] = 'weird';
      final r = relationshipFromJson(j);
      expect(r.type, RelationType.undecided);
      expect(r.pacing, RelPacing.slow);
      expect(r.startingPoint, StartingPoint.strangers);
      expect(r.events.first.category, TimelineKind.shift);
    });
  });

  group('ServerRelationshipBackend', () {
    late FakeBackendApi api;
    late ServerRelationshipBackend backend;

    setUp(() {
      api = FakeBackendApi();
      backend = ServerRelationshipBackend(api);
      api.rpcs['ensure_relationship'] = (p) => fixture();
      api.invokes['apply_correction'] = (b) => {'relationship': fixture(), 'note': null};
    });

    test('loading asks the database to create-or-return it, for the persona in use', () async {
      final r = await backend.load('c-1', 'p-1');
      expect(r.id, 'rel-1');
      expect(api.log, ['rpc ensure_relationship']);
    });

    test('the server picks the starting point from the character; the app only names the ids', () async {
      final sent = <Map<String, Object?>>[];
      api.rpcs['ensure_relationship'] = (p) {
        sent.add(p);
        return {...fixture(), 'startingPoint': 'together'};
      };
      final r = await backend.load('c-1', 'p-1', startingPoint: StartingPoint.rivals);
      expect(r.startingPoint, StartingPoint.together);
      expect(sent.single, {'p_character': 'c-1', 'p_persona': 'p-1'});
    });

    test('each thing you can do is one named action, and only the ask is sent', () async {
      await backend.correct('rel-1', const Values(trust: 50, affection: 40, attraction: 0, tension: 5), reason: 'We made up');
      await backend.setType('rel-1', RelationType.familial);
      await backend.setPacing('rel-1', RelPacing.fast);
      await backend.applyPreset('rel-1', 'family');
      await backend.setStartingPoint('rel-1', StartingPoint.together);
      await backend.saveStages('rel-1', ['A', 'B'], 2, true);
      await backend.addFact('rel-1', 'Text', locked: false);
      await backend.setFactLocked('rel-1', 'f1', true);
      await backend.removeFact('rel-1', 'f1');
      await backend.undo('rel-1', 'e1', reason: 'because');
      await backend.acceptSuggestion('rel-1', 's1');
      await backend.dismissSuggestion('rel-1', 's1');
      expect(api.invokeBodies, [
        {'action': 'correct', 'relationshipId': 'rel-1', 'values': {'trust': 50.0, 'affection': 40.0, 'attraction': 0.0, 'tension': 5.0}, 'reason': 'We made up'},
        {'action': 'set_type', 'relationshipId': 'rel-1', 'type': 'familial'},
        {'action': 'set_pacing', 'relationshipId': 'rel-1', 'pacing': 'fast'},
        {'action': 'apply_preset', 'relationshipId': 'rel-1', 'presetId': 'family'},
        {'action': 'set_starting_point', 'relationshipId': 'rel-1', 'startingPoint': 'together'},
        {'action': 'save_stages', 'relationshipId': 'rel-1', 'names': ['A', 'B'], 'current': 2, 'lock': true},
        {'action': 'add_fact', 'relationshipId': 'rel-1', 'text': 'Text', 'locked': false},
        {'action': 'set_fact_locked', 'relationshipId': 'rel-1', 'factId': 'f1', 'locked': true},
        {'action': 'remove_fact', 'relationshipId': 'rel-1', 'factId': 'f1'},
        {'action': 'undo', 'relationshipId': 'rel-1', 'eventId': 'e1', 'reason': 'because'},
        {'action': 'accept_suggestion', 'relationshipId': 'rel-1', 'suggestionId': 's1'},
        {'action': 'dismiss_suggestion', 'relationshipId': 'rel-1', 'suggestionId': 's1'},
      ]);
    });

    test('an edited message is judged by the server from the saved text; a switched-back version is recounted', () async {
      api.invokes['apply_correction'] = (b) => {
            'relationship': fixture(),
            'note': {'text': 'Trust grew', 'story': 'Something shifted between you.', 'entryId': 'e9'},
          };
      final u = await backend.editedMessage(relationshipId: 'rel-1', messageId: 'm1', text: 'ignored: the server reads it');
      expect(u.note?.entryId, 'e9');
      final r = await backend.recountProposal('rel-1', 'm2', 1);
      expect(r.note?.text, 'Trust grew');
      expect(api.invokeBodies.first.containsKey('text'), isFalse, reason: 'the app does not send the text');
      expect(api.invokeBodies.last, {'action': 'recount_proposal', 'relationshipId': 'rel-1', 'messageId': 'm2', 'altIndex': 1});
    });

    test('the app cannot submit a judgement of its own', () {
      expect(() => backend.userMessage(relationshipId: 'r', messageId: 'm', text: 't'), throwsUnsupportedError);
      expect(
        () => backend.modelProposal(
          relationshipId: 'r',
          messageId: 'm',
          kindId: 'rescue',
          evidence: 'e',
          reason: 'r',
          recentMessages: const [],
          characterFirst: 'V',
        ),
        throwsUnsupportedError,
      );
    });

    test('a server error stays an error the screen can handle', () async {
      api.invokes['apply_correction'] = (b) => throw const BackendException(404, 'not_found', 'Not found.');
      await expectLater(backend.setPacing('rel-1', RelPacing.slow), throwsA(isA<BackendException>()));
    });
  });

  group('ServerReplyStreamingService', () {
    late FakeBackendApi api;
    late ServerReplyStreamingService service;

    setUp(() {
      api = FakeBackendApi();
      service = ServerReplyStreamingService(api);
    });

    test('says it judges relationships itself', () {
      expect(service.handlesRelationship, isTrue);
      expect(FakeReplyStreamingService().handlesRelationship, isFalse);
    });

    test('sends ids and preferences, never the text or the prompt', () async {
      api.onStream = (fn, body) => events([('done', {'text': 'x'})]);
      await service.streamReply(request()).toList();
      expect(api.streamBodies.single, {
        'conversationId': 'cv-1',
        'personaId': 'p-1',
        'modelId': 'ember',
        'aiMessageId': 'm-ai',
        'altIndex': 0,
        'settings': {'length': 'long', 'style': 'literary', 'temperature': 0.7, 'maxTokens': 900, 'repetitionPenalty': 1.1, 'contextDepth': 40},
        'userMessageId': 'm-user',
      });
    });

    test('a rewrite names the reply it replaces and which version this is', () async {
      api.onStream = (fn, body) => events([('done', {'text': 'x'})]);
      await service.streamReply(request(userMessageId: null, replaceMessageId: 'm-ai', altIndex: 2)).toList();
      expect(api.streamBodies.single['replaceMessageId'], 'm-ai');
      expect(api.streamBodies.single['altIndex'], 2);
      expect(api.streamBodies.single.containsKey('userMessageId'), isFalse);
    });

    test('text arrives cumulatively; start and done carry notes, the relationship and free replies', () async {
      api.onStream = (fn, body) => events([
            ('start', {
              'userNote': {'text': 'Trust grew', 'story': 'Something shifted.', 'entryId': 'e1'},
              'relationship': fixture(),
              'usage': {'modelId': 'ember', 'used': 4, 'limit': 30},
            }),
            ('delta', {'text': 'Hello '}),
            ('delta', {'text': 'there.'}),
            ('done', {
              'text': 'Hello there.',
              'note': {'text': 'Trust grew a little', 'story': 'Something shifted.', 'entryId': 'e2'},
              'relationship': fixture(),
            }),
          ]);
      final infos = <ServerTurnInfo>[];
      final out = await service.streamReply(request(onInfo: infos.add)).toList();
      expect(out, ['Hello ', 'Hello there.']);
      expect(infos, hasLength(2));
      expect(infos[0].userNote?.entryId, 'e1');
      expect(infos[0].freeRepliesLeft, 26);
      expect(infos[0].modelId, 'ember');
      expect(infos[0].relationship?.id, 'rel-1');
      expect(infos[0].done, isFalse);
      expect(infos[1].done, isTrue);
      expect(infos[1].replyNote?.text, 'Trust grew a little');
    });

    test('the final text wins if the server tidied it (e.g. a trailing tag was removed)', () async {
      api.onStream = (fn, body) => events([
            ('delta', {'text': 'Hi there. '}),
            ('done', {'text': 'Hi there.'}),
          ]);
      expect(await service.streamReply(request()).toList(), ['Hi there. ', 'Hi there.']);
    });

    test('with animations off the reply comes once, at the end', () async {
      api.onStream = (fn, body) => events([
            ('delta', {'text': 'Hello '}),
            ('delta', {'text': 'there.'}),
            ('done', {'text': 'Hello there.'}),
          ]);
      expect(await service.streamReply(request(stream: false)).toList(), ['Hello there.']);
    });

    test('an error event, a limit, a dropped connection and being offline each say what happened', () async {
      api.onStream = (fn, body) => events([('start', {}), ('error', {'code': 'model_busy', 'message': 'busy'})]);
      await expectLater(
        service.streamReply(request()).toList(),
        throwsA(isA<ReplyException>().having((e) => e.isModelProblem, 'model problem', isTrue)),
      );

      final infos = <ServerTurnInfo>[];
      api.onStream = (fn, body) => Stream.error(BackendException(429, 'model_limit', 'No free replies left.', {
            'userNote': {'text': 'Trust grew', 'story': 's', 'entryId': 'e1'},
            'relationship': fixture(),
          }));
      await expectLater(
        service.streamReply(request(onInfo: infos.add)).toList(),
        throwsA(isA<ReplyException>().having((e) => e.code, 'code', 'model_limit')),
      );
      expect(infos.single.userNote?.entryId, 'e1', reason: 'what your message did is still shown');

      api.onStream = (fn, body) => events([('delta', {'text': 'half a repl'})]);
      await expectLater(service.streamReply(request()).toList(), throwsA(isA<OfflineException>()));

      api.offline = true;
      await expectLater(service.streamReply(request()).toList(), throwsA(isA<OfflineException>()));
    });

    test('cancelling stops listening to the server', () async {
      var cancelled = false;
      final c = StreamController<SseEvent>(onCancel: () => cancelled = true);
      api.onStream = (fn, body) => c.stream;
      final sub = service.streamReply(request()).listen((_) {});
      c.add(const SseEvent('delta', {'text': 'a'}));
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();
      expect(cancelled, isTrue);
    });
  });
}
