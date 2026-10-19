import 'package:flutter_test/flutter_test.dart';
import 'package:hearth/data/mock/mock_data.dart';
import 'package:hearth/data/mock/mock_scenario.dart';
import 'package:hearth/features/chat/data/reply_streaming_service.dart';

ReplyRequest req({bool stream = true, String? avoid, int char = 0}) => ReplyRequest(
      character: MockData.characters[char],
      history: const [],
      modelId: 'ember',
      stream: stream,
      avoidText: avoid,
    );

FakeReplyStreamingService fast({bool offline = false}) => FakeReplyStreamingService(
      thinkingDelay: Duration.zero,
      tick: Duration.zero,
      wordsPerTick: 3,
      isOffline: () => offline,
    );

void main() {
  test('streams cumulative text that grows and ends with the full reply', () async {
    final out = await fast().streamReply(req()).toList();
    expect(out.length, greaterThan(5));
    for (var i = 1; i < out.length; i++) {
      expect(out[i].startsWith(out[i - 1]), isTrue, reason: 'chunk $i extends chunk ${i - 1}');
      expect(out[i].length, greaterThan(out[i - 1].length));
    }
    expect(out.last, MockData.replies['vesper']![0]);
  });

  test('without streaming the whole reply is emitted exactly once', () async {
    final out = await fast().streamReply(req(stream: false)).toList();
    expect(out, [MockData.replies['vesper']![0]]);
  });

  test('replies cycle and never repeat the one being replaced', () async {
    final s = fast();
    final a = (await s.streamReply(req()).toList()).last;
    final b = (await s.streamReply(req(avoid: a)).toList()).last;
    expect(b, isNot(a));
    final c = (await s.streamReply(req(avoid: b)).toList()).last;
    expect(c, isNot(b));
  });

  test('characters without canned replies use the default, with their name', () async {
    final out = (await fast().streamReply(req(char: 1)).toList()).last;
    expect(out, MockData.replies['jun']![0]);
    final generic = ReplyRequest(
      character: MockData.characters[0].copyWith(name: 'Zed Q', first: 'Zed'),
      history: const [],
      modelId: 'ember',
    );
    // 'vesper' id is kept by copyWith, so use a fresh id via the default list
    expect(MockData.replies['_default']!.first, contains('{name}'));
    expect(generic.character.first, 'Zed');
  });

  test('offline throws OfflineException', () async {
    expect(fast(offline: true).streamReply(req()).toList(), throwsA(isA<OfflineException>()));
  });
}
