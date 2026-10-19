
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hearth/core/theme/theme_provider.dart';
import 'package:hearth/data/mock/mock_data.dart';
import 'package:hearth/data/mock/mock_scenario.dart';
import 'package:hearth/features/chat/data/chat_controller.dart';
import 'package:hearth/features/chat/data/conversation_repository.dart';
import 'package:hearth/features/chat/data/reply_streaming_service.dart';
import 'package:hearth/features/chat/domain/chat_models.dart';
import 'package:hearth/features/settings/data/model_usage.dart';
import 'package:shared_preferences/shared_preferences.dart';

const cid = 'c1'; // Vesper, pinned, 5 messages (c1c has two alts)

Future<ProviderContainer> setup({
  Duration thinking = const Duration(milliseconds: 20),
  Duration tick = const Duration(milliseconds: 15),
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final c = ProviderContainer(overrides: [
    sharedPreferencesProvider.overrideWithValue(prefs),
    mockLatencyProvider.overrideWithValue(Duration.zero),
    replyStreamingServiceProvider.overrideWith((ref) => FakeReplyStreamingService(
          thinkingDelay: thinking,
          tick: tick,
          wordsPerTick: 4,
          isOffline: () {
            if (ref.read(mockFailNextReplyProvider)) {
              ref.read(mockFailNextReplyProvider.notifier).state = false;
              return true;
            }
            return false;
          },
        )),
  ]);
  addTearDown(c.dispose);
  await c.read(conversationsProvider.future);
  c.listen(chatControllerProvider(cid), (_, _) {});
  return c;
}

Future<void> idle(ProviderContainer c) async {
  for (var i = 0; i < 400; i++) {
    if (!c.read(chatControllerProvider(cid)).busy) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail('generation never finished');
}

Conversation conv(ProviderContainer c) => c.read(conversationProvider(cid))!;
ChatController ctl(ProviderContainer c) => c.read(chatControllerProvider(cid).notifier);
ChatUiState ui(ProviderContainer c) => c.read(chatControllerProvider(cid));

void main() {
  test('send adds the user message, shows thinking, streams, then finishes', () async {
    final c = await setup();
    final before = conv(c).messages.length;
    final statuses = <GenStatus>[];
    c.listen(chatControllerProvider(cid), (_, n) {
      if (statuses.isEmpty || statuses.last != n.status) statuses.add(n.status);
    });

    final f = ctl(c).send('  Tell me about the letters. ');
    await f;
    expect(conv(c).messages.length, before + 2);
    expect(conv(c).messages[before].isUser, isTrue);
    expect(conv(c).messages[before].text, 'Tell me about the letters.');
    expect(ui(c).status, GenStatus.thinking);
    expect(conv(c).messages.last.text, isEmpty, reason: 'placeholder while thinking');

    await idle(c);
    expect(statuses, [GenStatus.thinking, GenStatus.streaming, GenStatus.idle]);
    expect(conv(c).messages.last.role, MessageRole.ai);
    expect(conv(c).messages.last.text, contains('kettle'), reason: 'first canned Vesper reply');
    expect(ui(c).activeId, isNull);
  });

  test('empty or whitespace messages are ignored; busy blocks a second send', () async {
    final c = await setup();
    final before = conv(c).messages.length;
    await ctl(c).send('   ');
    expect(conv(c).messages.length, before);
    await ctl(c).send('one two three four');
    await ctl(c).send('should be ignored while busy');
    await idle(c);
    expect(conv(c).messages.length, before + 2);
  });

  test('streaming is throttled: far fewer writes than chunks arrive', () async {
    final c = await setup(thinking: Duration.zero, tick: const Duration(milliseconds: 5));
    var writes = 0;
    c.listen(conversationProvider(cid), (_, _) => writes++);
    await ctl(c).send('please go on with the story');
    await idle(c);
    // The canned reply is ~60 words => ~15 chunks at 4 words/chunk, 5ms apart
    // (~75ms of streaming). A 60ms throttle must collapse those.
    expect(writes, lessThan(12));
  });

  test('stop keeps partial text with an ellipsis and marks it stopped', () async {
    final c = await setup(tick: const Duration(milliseconds: 40));
    await ctl(c).send('go on then please');
    for (var i = 0; i < 200 && ui(c).status != GenStatus.streaming; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    await Future<void>.delayed(const Duration(milliseconds: 90));
    final id = ui(c).activeId!;
    final result = ctl(c).stop();
    expect(result, StopResult.kept);
    final m = conv(c).messages.firstWhere((m) => m.id == id);
    expect(m.text, endsWith('…'));
    expect(m.text.length, lessThan(60 * 8));
    expect(ui(c).stoppedIds, contains(id));
    expect(ui(c).busy, isFalse);
    // No more text arrives afterwards.
    final frozen = m.text;
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(conv(c).messages.firstWhere((m) => m.id == id).text, frozen);
  });

  test('stop while still thinking removes the placeholder and refunds the reply', () async {
    final c = await setup(thinking: const Duration(milliseconds: 300));
    final before = conv(c).messages.length;
    final left = c.read(modelUsageProvider)['ember'];
    await ctl(c).send('hello there my friend');
    expect(c.read(modelUsageProvider)['ember'], left! - 1);
    expect(ctl(c).stop(), StopResult.removed);
    expect(conv(c).messages.length, before + 1, reason: 'user message stays, reply placeholder gone');
    expect(c.read(modelUsageProvider)['ember'], left);
    expect(ctl(c).stop(), StopResult.none);
  });

  test('rewrite adds an alt, shows it, and keeps the old one', () async {
    final c = await setup();
    final last = conv(c).messages.last;
    expect(last.alts, hasLength(1));
    await ctl(c).rewrite(last.id);
    await idle(c);
    final m = conv(c).messages.last;
    expect(m.id, last.id, reason: 'same message, not a new one');
    expect(m.alts, hasLength(2));
    expect(m.altIndex, 1);
    expect(m.alts[0], last.alts[0]);
    expect(m.alts[1], isNotEmpty);
    expect(m.alts[1], isNot(m.alts[0]));
  });

  test('alt navigation clamps and persists on the message', () async {
    final c = await setup();
    const id = 'c1c'; // has two alts, visible 0
    ctl(c).setAlt(id, 1);
    expect(conv(c).messages.firstWhere((m) => m.id == id).altIndex, 1);
    ctl(c).setAlt(id, 9);
    expect(conv(c).messages.firstWhere((m) => m.id == id).altIndex, 1);
    ctl(c).setAlt(id, -4);
    expect(conv(c).messages.firstWhere((m) => m.id == id).altIndex, 0);
  });

  test('edit replaces only the visible alt and rejects empty text', () async {
    final c = await setup();
    ctl(c).setAlt('c1c', 1);
    expect(ctl(c).edit('c1c', ' New words. '), isTrue);
    final m = conv(c).messages.firstWhere((m) => m.id == 'c1c');
    expect(m.alts[1], 'New words.');
    expect(m.alts[0], contains('kettle'));
    expect(ctl(c).edit('c1c', '   '), isFalse);
    expect(conv(c).messages.firstWhere((m) => m.id == 'c1c').alts[1], 'New words.');
  });

  test('story Continue writes a reply without adding a user message', () async {
    final c = await setup();
    final before = conv(c).messages.length;
    await ctl(c).continueStory();
    await idle(c);
    expect(conv(c).messages.length, before + 1);
    expect(conv(c).messages.last.role, MessageRole.ai);
  });

  test('animations off: the full reply is written without streaming', () async {
    final c = await setup();
    await ctl(c).send('tell me everything now', animate: false);
    await idle(c);
    expect(conv(c).messages.last.text, contains('kettle'));
    expect(conv(c).messages.last.text, endsWith('"'));
    expect(ui(c).stoppedIds, isEmpty);
  });

  group('model limit flow', () {
    test('Ember has 2 free replies; the 3rd send hits the limit and keeps the message', () async {
      final c = await setup(thinking: Duration.zero, tick: Duration.zero);
      for (final t in ['first message here', 'second message here']) {
        await ctl(c).send(t);
        await idle(c);
      }
      expect(c.read(modelUsageProvider)['ember'], 0);
      final before = conv(c).messages.length;

      await ctl(c).send('third message here');
      final e = ui(c).error;
      expect(e, isA<ModelUnavailableError>());
      expect((e as ModelUnavailableError).modelId, 'ember');
      expect(ui(c).busy, isFalse);
      expect(conv(c).messages.length, before + 1, reason: 'user message kept, no reply');
      expect(conv(c).messages.last.text, 'third message here');
      expect(c.read(modelStatusProvider('ember')).reason, 'Daily limit reached · resets 07:00');
    });

    test('switch model → retry resends and finishes (journey F)', () async {
      final c = await setup(thinking: Duration.zero, tick: Duration.zero);
      c.read(modelUsageProvider.notifier).state = {'ember': 0, 'lumen': 41};
      await ctl(c).send('please continue the story');
      expect(ui(c).error, isA<ModelUnavailableError>());

      c.read(selectedModelIdProvider.notifier).select('lumen');
      await ctl(c).retry();
      await idle(c);
      expect(ui(c).error, isNull);
      expect(conv(c).messages.last.role, MessageRole.ai);
      expect(conv(c).messages.last.text, isNotEmpty);
      expect(c.read(modelUsageProvider)['lumen'], 40);
      expect(c.read(modelUsageProvider)['ember'], 0);
    });

    test('a busy model is unavailable with its own reason', () async {
      final c = await setup();
      c.read(selectedModelIdProvider.notifier).select('atlas');
      await ctl(c).send('anyone there at all');
      expect(ui(c).error, isA<ModelUnavailableError>());
      expect(c.read(modelStatusProvider('atlas')).reason, 'Busy right now — try again later');
    });

    test('retry of a failed Rewrite rewrites again, not a new message', () async {
      final c = await setup(thinking: Duration.zero, tick: Duration.zero);
      c.read(modelUsageProvider.notifier).state = {'ember': 0, 'lumen': 41};
      final last = conv(c).messages.last;
      await ctl(c).rewrite(last.id);
      expect((ui(c).error as ModelUnavailableError).regenId, last.id);
      c.read(selectedModelIdProvider.notifier).select('lumen');
      await ctl(c).retry();
      await idle(c);
      expect(conv(c).messages.last.id, last.id);
      expect(conv(c).messages.last.alts, hasLength(2));
    });
  });

  group('offline', () {
    test('a failed reply keeps the user message, refunds, and Try again works', () async {
      final c = await setup();
      final left = c.read(modelUsageProvider)['ember'];
      c.read(mockFailNextReplyProvider.notifier).state = true;
      final before = conv(c).messages.length;

      await ctl(c).send('are you there still');
      await idle(c);
      expect(ui(c).error, isA<OfflineChatError>());
      expect(conv(c).messages.length, before + 1);
      expect(conv(c).messages.last.isUser, isTrue);
      expect(c.read(modelUsageProvider)['ember'], left);

      await ctl(c).retry();
      await idle(c);
      expect(ui(c).error, isNull);
      expect(conv(c).messages.last.role, MessageRole.ai);
    });
  });

  test('startNew creates a chat with the greeting, first in the list, in chat mode', () async {
    final c = await setup();
    final jun = MockData.characters[1];
    final id = c.read(conversationsProvider.notifier).startNew(jun);
    final list = c.read(conversationsProvider).requireValue;
    expect(list.first.id, id);
    expect(list.first.title, 'New chat with Jun');
    expect(list.first.messages.single.text, jun.greeting);
    expect(list.first.messages.single.role, MessageRole.ai);
    expect(list.first.mode, ChatMode.chat);
    expect(list.length, 4);
  });

  test('mode, rename, pin and delete persist on the conversation', () async {
    final c = await setup();
    final n = c.read(conversationsProvider.notifier);
    n.setMode(cid, ChatMode.story);
    expect(conv(c).mode, ChatMode.story);
    n.rename(cid, 'Renamed');
    expect(conv(c).title, 'Renamed');
    n.togglePin(cid);
    expect(conv(c).pinned, isFalse);
    await n.delete(cid);
    expect(c.read(conversationProvider(cid)), isNull);
  });
}
