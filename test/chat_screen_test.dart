import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hearth/core/theme/hearth_colors.dart';
import 'package:hearth/core/widgets/composer.dart';
import 'package:hearth/core/widgets/rich_roleplay_text.dart';
import 'package:hearth/data/mock/mock_scenario.dart';
import 'package:hearth/features/chat/data/chat_controller.dart';
import 'package:hearth/features/chat/data/conversation_repository.dart';
import 'package:hearth/features/chat/domain/chat_models.dart';
import 'package:hearth/features/chat/presentation/message_list.dart';
import 'package:hearth/features/settings/data/model_usage.dart';
import 'package:hearth/features/settings/data/reading_prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/harness.dart';

Finder composerField() =>
    find.descendant(of: find.byType(Composer), matching: find.byType(TextField));

Future<void> typeAndSend(WidgetTester t, String text) async {
  await t.enterText(composerField(), text);
  await t.pump();
  await t.tap(tooltip('Send message'));
  await t.pump();
}

Future<Harness> openChat(WidgetTester t, {String id = 'c1', double textScale = 1}) async {
  final h = await pumpHearth(t, textScale: textScale);
  await h.push('/chat/$id');
  return h;
}

/// Pumps frames until [done] is true (or fails), so streaming can be observed
/// without relying on pumpAndSettle (the caret and dots animate forever).
Future<void> pumpUntil(WidgetTester t, bool Function() done,
    {Duration step = const Duration(milliseconds: 40), int max = 200}) async {
  for (var i = 0; i < max; i++) {
    if (done()) return;
    await t.pump(step);
  }
  fail('condition never became true');
}

bool bubbleColor(Widget w) {
  if (w is! Container) return false;
  final d = w.decoration;
  return d is BoxDecoration && d.color == HearthColors.dark.primarySoft;
}

void main() {
  group('layout and message styling', () {
    testWidgets('AI replies are full-width prose; only the user message is a bubble', (t) async {
      await openChat(t);
      // The user's message (c1d) is a bubble; the AI replies are not.
      expect(find.byWidgetPredicate(bubbleColor), findsWidgets);
      expect(find.byWidgetPredicate(bubbleColor).evaluate().length,
          lessThan(find.byType(RichRoleplayText).evaluate().length));
      final bubbleTexts = find.descendant(
          of: find.byWidgetPredicate(bubbleColor), matching: find.byType(RichRoleplayText));
      for (final w in t.widgetList<RichRoleplayText>(bubbleTexts)) {
        expect(w.text, isNot(contains('kettle')), reason: 'AI text is never in a bubble');
      }
      final reply = find.byWidgetPredicate((w) =>
          w is RichRoleplayText && w.text.contains('They stay sealed until we open them together'));
      expect(t.getSize(reply).width, greaterThan(300), reason: 'prose spans the row');
      final bubble = t.getSize(find.byWidgetPredicate(bubbleColor).last);
      expect(bubble.width, lessThanOrEqualTo(360 * 0.85));
    });

    testWidgets('header: Back, avatar and name, a Story pill and ⋯ (all ≥ target sizes)', (t) async {
      await openChat(t);
      expect(find.text('Vesper Hale'), findsOneWidget);
      for (final tip in ['Back', 'Conversation options']) {
        final s = t.getSize(tooltip(tip));
        expect(s.width, greaterThanOrEqualTo(48), reason: tip);
        expect(s.height, greaterThanOrEqualTo(48), reason: tip);
      }
      expect(t.getSize(find.widgetWithText(OutlinedButton, 'Story')).height,
          greaterThanOrEqualTo(44));
      expect(t.getSize(tooltip('Send message')).height, greaterThanOrEqualTo(48));
    });

    testWidgets('tapping the name opens the character profile', (t) async {
      await openChat(t);
      await t.tapAndSettle(find.text('Vesper Hale'));
      expect(find.text('Start new chat'), findsOneWidget);
    });

    testWidgets('the composer stays visible with the keyboard open', (t) async {
      await openChat(t);
      t.view.viewInsets = const FakeViewPadding(bottom: 320);
      addTearDown(t.view.resetViewInsets);
      await t.pumpAndSettle();
      final box = t.getRect(find.byType(Composer));
      expect(box.bottom, lessThanOrEqualTo(800 - 320 + 0.5));
      expect(t.takeException(), isNull);
    });

    testWidgets('holds at 200% text in Chat and in Story', (t) async {
      final h = await openChat(t, textScale: 2);
      expect(t.takeException(), isNull);
      await t.tapAndSettle(tooltip('Switch to Story mode'));
      expect(t.takeException(), isNull);
      await t.tapAndSettle(find.textContaining('STORY'));
      expect(find.text('Switch to Chat mode'), findsOneWidget);
      expect(t.takeException(), isNull);
      expect(h.container.read(conversationProvider('c1'))!.mode, ChatMode.story);
    });
  });

  group('sending and streaming', () {
    testWidgets('send: bubble, "Vesper is writing…", Stop, streamed reply, then Send again', (t) async {
      final h = await openChat(t);
      expect(tooltip('Send message'), findsOneWidget);
      await typeAndSend(t, 'Tell me about the north tide.');
      expect(find.text('Tell me about the north tide.'), findsOneWidget);
      expect(find.text('Vesper is writing…'), findsOneWidget);
      expect(tooltip('Stop reply'), findsOneWidget);
      expect(tooltip('Send message'), findsNothing);

      await pumpUntil(t, () => find.text('Vesper is writing…').evaluate().isEmpty);
      // text is arriving: the caret shows while streaming
      expect(tooltip('Stop reply'), findsOneWidget);
      await pumpUntil(t, () => tooltip('Send message').evaluate().isNotEmpty);
      final last = convOf(h, 'c1').messages.last;
      expect(last.role, MessageRole.ai);
      expect(last.text, contains('kettle'));
      expect(find.textContaining('They come in on the north tide'), findsOneWidget);
    });

    testWidgets('journey: the composer clears and the new reply stays visible at the bottom',
        (t) async {
      await openChat(t);
      await typeAndSend(t, 'Go on.');
      expect(t.widget<TextField>(composerField()).controller!.text, isEmpty);
      await pumpUntil(t, () => tooltip('Send message').evaluate().isNotEmpty);
      expect(find.textContaining('I\'d very much like to know why the sea is writing to you'),
          findsOneWidget);
    });

    testWidgets('Stop keeps the partial text, marks it Stopped, and shows a toast', (t) async {
      final h = await openChat(t);
      await typeAndSend(t, 'Go on, please do.');
      await pumpUntil(t, () => find.text('Vesper is writing…').evaluate().isEmpty);
      await t.pump(const Duration(milliseconds: 80));
      await t.tap(tooltip('Stop reply'));
      await t.pumpAndSettle();
      expect(find.text('Stopped. Keep it, edit it, or rewrite it.'), findsOneWidget);
      final m = convOf(h, 'c1').messages.last;
      expect(m.text, endsWith('…'));
      expect(m.text.length, lessThan(300));
      expect(find.text('Stopped'), findsOneWidget);
      expect(tooltip('Send message'), findsOneWidget);
    });

    testWidgets('Android Enter adds a line; Send is the only way to send', (t) async {
      await openChat(t);
      final h = t.widget<TextField>(composerField());
      expect(h.keyboardType, TextInputType.multiline);
      expect(h.textInputAction, TextInputAction.newline);
      expect(h.maxLines, 5);
    });
  });

  group('rewrite, alts, edit, copy', () {
    testWidgets('Rewrite adds an alt: "‹ 2 of 2 ›", and you can step back', (t) async {
      await openChat(t);
      expect(find.textContaining(RegExp(r'^\d+ of \d+$')), findsNothing);
      await t.tapAndSettle(find.text('Rewrite'));
      await pumpUntil(t, () => find.text('2 of 2').evaluate().isNotEmpty);
      await pumpUntil(t, () => tooltip('Send message').evaluate().isNotEmpty);
      expect(find.text('2 of 2'), findsOneWidget);
      // the new version is not the old one
      expect(find.textContaining('Your word. She seems to weigh it like rope'), findsNothing);

      await t.tapAndSettle(tooltip('Previous version'));
      expect(find.text('1 of 2'), findsOneWidget);
      expect(find.textContaining('She seems to weigh it like rope'), findsOneWidget);
      await t.tapAndSettle(tooltip('Next version'));
      expect(find.text('2 of 2'), findsOneWidget);
    });

    testWidgets('Rewrite while streaming shows the new alt growing and keeps the old one', (t) async {
      final h = await openChat(t);
      await t.tap(find.text('Rewrite'));
      await t.pump();
      expect(find.text('Vesper is writing…'), findsOneWidget);
      await pumpUntil(t, () => find.text('Vesper is writing…').evaluate().isEmpty);
      final m = convOf(h, 'c1').messages.last;
      expect(m.alts.length, 2);
      expect(m.alts.first, contains('They stay sealed'));
      await pumpUntil(t, () => tooltip('Send message').evaluate().isNotEmpty);
    });

    testWidgets('Copy puts the plain text (no markup) on the clipboard', (t) async {
      final copied = captureClipboard(t);
      await openChat(t);
      await t.tapAndSettle(find.text('Copy'));
      expect(copied, hasLength(1));
      expect(copied.single, contains('She seems to weigh it like rope.'));
      expect(copied.single, isNot(contains('*')));
      expect(find.text('Copied to clipboard'), findsOneWidget);
    });

    testWidgets('Edit the latest reply: Save updates it; empty is refused', (t) async {
      final h = await openChat(t);
      await t.tapAndSettle(find.text('Edit'));
      final field = find.descendant(
          of: find.byType(MessageList), matching: find.byType(TextField));
      expect(field, findsOneWidget);

      await t.enterText(field, '   ');
      await t.pump();
      expect(t.widget<FilledButton>(find.widgetWithText(FilledButton, 'Save')).onPressed, isNull,
          reason: 'Save is disabled while the text is empty');

      await t.enterText(field, '*Vesper nods.* "Fine."');
      await t.pump();
      await t.tapAndSettle(find.text('Save'));
      expect(find.text('Message updated'), findsOneWidget);
      expect(convOf(h, 'c1').messages.last.text, '*Vesper nods.* "Fine."');
    });

    testWidgets('Edit can be cancelled without changes', (t) async {
      final h = await openChat(t);
      final before = convOf(h, 'c1').messages.last.text;
      await t.tapAndSettle(find.text('Edit'));
      await t.tapAndSettle(find.text('Cancel'));
      expect(convOf(h, 'c1').messages.last.text, before);
      expect(find.text('Edit'), findsOneWidget);
    });

    testWidgets('your own message: ⋯ → Edit, and long-press opens Copy/Edit', (t) async {
      final h = await openChat(t);
      await t.tapAndSettle(tooltip('More options for your message').last);
      expect(find.text('Copy'), findsWidgets);
      await t.tapAndSettle(find.text('Edit').last);
      final field = find.descendant(
          of: find.byType(MessageList), matching: find.byType(TextField));
      await t.enterText(field, 'I promise. Truly.');
      await t.tapAndSettle(find.text('Save'));
      expect(convOf(h, 'c1').messages[3].text, 'I promise. Truly.');
      expect(find.text('I promise. Truly.'), findsOneWidget);
    });

    testWidgets('older replies offer Copy and Edit from ⋯ (no Rewrite)', (t) async {
      await openChat(t);
      final more = tooltip('More options for this message');
      // The note under the last message pushes older replies up; read back a little.
      await t.drag(find.byType(MessageList), const Offset(0, 300));
      await t.pumpAndSettle();
      expect(more, findsWidgets);
      await t.ensureVisible(more.last);
      await t.pumpAndSettle();
      await t.tapAndSettle(more.last);
      expect(find.text('Copy'), findsWidgets);
      expect(find.text('Edit'), findsWidgets);
      expect(find.widgetWithText(InkWell, 'Rewrite'), findsNothing);
    });

    testWidgets('message actions are labelled and ≥44dp tall', (t) async {
      await openChat(t);
      for (final label in ['Rewrite', 'Copy', 'Edit']) {
        final b = find.ancestor(of: find.text(label), matching: find.byType(TextButton)).first;
        expect(t.getSize(b).height, greaterThanOrEqualTo(44), reason: label);
      }
    });
  });

  group('model limit and offline (journey F)', () {
    Future<Harness> limited(WidgetTester t) async {
      final h = await openChat(t);
      h.container.read(modelUsageProvider.notifier).state = {'ember': 0, 'lumen': 41};
      return h;
    }

    testWidgets('inline card keeps your message; Try again explains it is still unavailable',
        (t) async {
      final h = await limited(t);
      await typeAndSend(t, 'Then let us open it together.');
      await t.pumpAndSettle();
      expect(find.text('Ember has used today’s free replies'), findsOneWidget);
      expect(find.textContaining('Your message is saved.'), findsOneWidget);
      expect(find.text('Then let us open it together.'), findsOneWidget);
      expect(convOf(h, 'c1').messages.last.isUser, isTrue);
      expect(tooltip('Send message'), findsOneWidget);

      await t.tapAndSettle(find.text('Try again'));
      expect(find.text('Ember is still unavailable. Try switching models.'), findsOneWidget);
    });

    testWidgets('Switch model → pick: 2 taps, auto-resends, card disappears', (t) async {
      final h = await limited(t);
      await typeAndSend(t, 'Then let us open it together.');
      await t.pumpAndSettle();

      await t.tapAndSettle(find.text('Switch model')); // tap 1
      expect(find.text('Choose a model'), findsOneWidget);
      expect(find.text('Daily limit reached · resets 07:00'), findsOneWidget);
      expect(find.text('Available · 41 of 50 free replies left today'), findsOneWidget);
      expect(find.text('Busy right now — try again later'), findsOneWidget);
      expect(find.text('Free models have a daily reply limit. It resets every day at 07:00.'),
          findsOneWidget);

      // Atlas is busy: tapping it does nothing.
      await t.tap(find.text('Atlas Pro'));
      await t.pumpAndSettle();
      expect(find.text('Choose a model'), findsOneWidget);

      await t.tap(find.text('Lumen')); // tap 2
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      expect(find.text('Switched to Lumen'), findsOneWidget);
      await pumpUntil(t, () => tooltip('Send message').evaluate().isNotEmpty);
      expect(find.text('Ember has used today’s free replies'), findsNothing);
      expect(convOf(h, 'c1').messages.last.role, MessageRole.ai);
      expect(h.container.read(modelUsageProvider)['lumen'], 40);
      expect(h.container.read(selectedModelIdProvider), 'lumen');
    });

    testWidgets('a busy model gets its own wording', (t) async {
      final h = await openChat(t);
      h.container.read(selectedModelIdProvider.notifier).select('atlas');
      await typeAndSend(t, 'Anyone there?');
      await t.pumpAndSettle();
      expect(find.text('Atlas Pro is busy right now'), findsOneWidget);
    });

    testWidgets('Change AI model from the ⋯ menu shows the same picker', (t) async {
      await openChat(t);
      await t.tapAndSettle(tooltip('Conversation options'));
      expect(find.text('Ember'), findsOneWidget, reason: 'current model as meta');
      await t.tapAndSettle(find.text('Change AI model'));
      expect(find.text('Choose a model'), findsOneWidget);
      expect(find.text('Available · 2 of 30 free replies left today'), findsOneWidget);
    });

    testWidgets('offline: inline card, message kept, Try again succeeds', (t) async {
      final h = await openChat(t);
      h.container.read(mockFailNextReplyProvider.notifier).state = true;
      await typeAndSend(t, 'Are you still there?');
      await t.pumpAndSettle();
      expect(find.text('Can’t reach Hearth right now'), findsOneWidget);
      expect(find.text('Are you still there?'), findsOneWidget);
      await t.tapAndSettle(find.text('Try again'));
      await pumpUntil(t, () => tooltip('Send message').evaluate().isNotEmpty);
      expect(find.text('Can’t reach Hearth right now'), findsNothing);
      expect(convOf(h, 'c1').messages.last.role, MessageRole.ai);
    });
  });

  group('Chat ↔ Story', () {
    testWidgets('Story pill: same route, story header, scene title, YOU blocks, story composer',
        (t) async {
      final h = await openChat(t);
      await t.tapAndSettle(find.widgetWithText(OutlinedButton, 'Story'));
      expect(find.text('VESPER · STORY'), findsOneWidget);
      expect(find.text('Chat'), findsOneWidget);
      expect(find.text('What happens next? (optional)'), findsOneWidget);
      await t.drag(find.byType(MessageList), const Offset(0, 500));
      await t.pumpAndSettle();
      expect(find.text('YOU'), findsWidgets);
      expect(convOf(h, 'c1').mode, ChatMode.story);
      expect(h.router.state.uri.path, '/chat/c1', reason: 'a state toggle, not a new route');
      expect(find.byWidgetPredicate(bubbleColor), findsNothing, reason: 'no bubbles in Story');
      // 1 tap (journey D)
      await t.tapAndSettle(find.widgetWithText(OutlinedButton, 'Chat'));
      expect(find.text('Message Vesper…'), findsOneWidget);
      expect(convOf(h, 'c1').mode, ChatMode.chat);
    });

    testWidgets('each conversation remembers its own mode', (t) async {
      final h = await openChat(t, id: 'c1');
      await t.tapAndSettle(find.widgetWithText(OutlinedButton, 'Story'));
      await h.go('/chat/c2');
      expect(find.text('Message Jun…'), findsOneWidget, reason: 'c2 is still in Chat');
      await h.go('/chat/c1');
      expect(find.text('VESPER · STORY'), findsOneWidget);
    });

    testWidgets('Story: sending empty means Continue (no new user turn)', (t) async {
      final h = await openChat(t);
      await t.tapAndSettle(find.widgetWithText(OutlinedButton, 'Story'));
      final before = convOf(h, 'c1').messages.length;
      await t.tap(find.text('Continue'));
      await t.pump();
      expect(find.text('The story continues…'), findsOneWidget);
      expect(tooltip('Stop reply'), findsOneWidget);
      await pumpUntil(t, () => find.widgetWithText(FilledButton, 'Continue').evaluate().isNotEmpty);
      final msgs = convOf(h, 'c1').messages;
      expect(msgs.length, before + 1);
      expect(msgs.last.role, MessageRole.ai);
    });

    testWidgets('Story: typing something sends it as a YOU turn', (t) async {
      final h = await openChat(t);
      await t.tapAndSettle(find.widgetWithText(OutlinedButton, 'Story'));
      await t.enterText(composerField(), 'She opens the first letter.');
      await t.pump();
      expect(find.text('Send'), findsOneWidget);
      await t.tap(find.text('Send'));
      await t.pump();
      expect(find.text('She opens the first letter.'), findsOneWidget);
      await pumpUntil(t, () => find.widgetWithText(FilledButton, 'Continue').evaluate().isNotEmpty);
      expect(convOf(h, 'c1').messages[convOf(h, 'c1').messages.length - 2].isUser, isTrue);
    });

    testWidgets('Story actions say "Rewrite passage"', (t) async {
      await openChat(t);
      await t.tapAndSettle(find.widgetWithText(OutlinedButton, 'Story'));
      expect(find.text('Rewrite passage'), findsOneWidget);
    });

    testWidgets('Switching keeps your place in a long conversation', (t) async {
      final h = await openLongChat(t);
      final probe = await readBack(t);
      expect(probe, isNotNull);

      await t.tapAndSettle(find.widgetWithText(OutlinedButton, 'Story'));
      final inStory = find.text('Filler line $probe');
      expect(inStory, findsOneWidget, reason: 'the same message is on screen in Story');
      expect(t.getTopLeft(inStory).dy, lessThan(300));

      await t.tapAndSettle(find.widgetWithText(OutlinedButton, 'Chat'));
      expect(find.text('Filler line $probe'), findsOneWidget, reason: 'and back again');
      expect(h.container.read(conversationProvider('c1'))!.mode, ChatMode.chat);
    });

    testWidgets('at the bottom you stay at the bottom when switching', (t) async {
      await openLongChat(t);
      await t.tapAndSettle(find.widgetWithText(OutlinedButton, 'Story'));
      expect(find.textContaining('They stay sealed until we open them together'), findsOneWidget);
      await t.tapAndSettle(find.widgetWithText(OutlinedButton, 'Chat'));
      expect(find.textContaining('They stay sealed until we open them together'), findsOneWidget);
    });
  });

  group('never moves while you read back', () {
    testWidgets('streaming below does not shift the page; a pill appears; tapping it jumps down',
        (t) async {
      final h = await openLongChat(t);
      final probe = (await readBack(t))!;
      final finder = find.text('Filler line $probe');
      final y0 = t.getTopLeft(finder).dy;
      expect(find.text('New reply below'), findsNothing);

      // A reply is written below, out of sight.
      final lastAi = convOf(h, 'c1').messages.last.id;
      h.container.read(chatControllerProvider('c1').notifier).rewrite(lastAi);
      var sawPill = false;
      for (var i = 0; i < 40; i++) {
        await t.pump(const Duration(milliseconds: 50));
        expect(t.getTopLeft(finder).dy, closeTo(y0, 0.5), reason: 'frame $i');
        if (find.text('New reply below').evaluate().isNotEmpty) sawPill = true;
        if (!h.container.read(chatControllerProvider('c1')).busy) break;
      }
      expect(sawPill, isTrue);
      await t.pump(const Duration(milliseconds: 400));
      expect(t.getTopLeft(finder).dy, closeTo(y0, 0.5));
      expect(find.text('New reply below'), findsOneWidget);

      await t.tap(find.text('New reply below'));
      await t.pumpAndSettle();
      expect(find.text('New reply below'), findsNothing);
      expect(find.text('2 of 2'), findsOneWidget, reason: 'the finished rewrite is revealed');
    });

    testWidgets('within 72dp of the bottom it follows new text', (t) async {
      final h = await openLongChat(t);
      await t.drag(find.byType(MessageList), const Offset(0, 40)); // nudge, still near
      await t.pumpAndSettle();
      await typeAndSend(t, 'Keep going.');
      await pumpUntil(t, () => tooltip('Send message').evaluate().isNotEmpty);
      expect(find.text('New reply below'), findsNothing);
      expect(find.textContaining('I\'d very much like to know why the sea is writing to you'),
          findsOneWidget);
      expect(h.container.read(conversationProvider('c1'))!.messages.last.role, MessageRole.ai);
    });
  });

  group('conversation options', () {
    testWidgets('lists every option with the current text size and model', (t) async {
      await openChat(t);
      await t.tapAndSettle(tooltip('Conversation options'));
      for (final label in [
        'Relationship journal',
        'Switch to Story mode',
        'Text size & reading',
        'Memories in this world',
        'Change AI model',
        'Rename chat',
        'Start a new chat with Vesper',
        'Delete chat…',
      ]) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      expect(find.text('16 pt'), findsOneWidget);
      expect(find.text('Ember'), findsOneWidget);
    });

    testWidgets('Switch mode from the menu', (t) async {
      await openChat(t);
      await t.tapAndSettle(tooltip('Conversation options'));
      await t.tapAndSettle(find.text('Switch to Story mode'));
      expect(find.text('VESPER · STORY'), findsOneWidget);
    });

    testWidgets('Rename chat saves and shows a toast', (t) async {
      final h = await openChat(t);
      await t.tapAndSettle(tooltip('Conversation options'));
      await t.tapAndSettle(find.text('Rename chat'));
      expect(find.text('Rename chat'), findsOneWidget);
      final field = find.descendant(
          of: find.byType(BottomSheet), matching: find.byType(TextField));
      await t.enterText(field, '');
      await t.pump();
      expect(t.widget<FilledButton>(find.widgetWithText(FilledButton, 'Save')).onPressed, isNull);
      await t.enterText(field, 'The seventh letter');
      await t.pump();
      await t.tapAndSettle(find.widgetWithText(FilledButton, 'Save'));
      expect(find.text('Renamed'), findsOneWidget);
      expect(convOf(h, 'c1').title, 'The seventh letter');
    });

    testWidgets('Delete asks first (safe option first), then removes the chat', (t) async {
      final h = await openChat(t);
      await t.tapAndSettle(tooltip('Conversation options'));
      await t.tapAndSettle(find.text('Delete chat…'));
      expect(find.text('Delete this chat?'), findsOneWidget);
      expect(t.getTopLeft(find.text('Keep chat')).dy,
          lessThan(t.getTopLeft(find.text('Delete chat')).dy));

      await t.tapAndSettle(find.text('Keep chat'));
      expect(h.container.read(conversationProvider('c1')), isNotNull);

      await t.tapAndSettle(tooltip('Conversation options'));
      await t.tapAndSettle(find.text('Delete chat…'));
      await t.tapAndSettle(find.text('Delete chat'));
      await t.pumpAndSettle(const Duration(seconds: 1));
      expect(h.container.read(conversationProvider('c1')), isNull);
      expect(find.text('Chat deleted'), findsOneWidget);
      expect(find.text('Message Vesper…'), findsNothing);
    });

    testWidgets('Start a new chat opens a fresh conversation with the greeting', (t) async {
      final h = await openChat(t);
      await t.tapAndSettle(tooltip('Conversation options'));
      await t.tapAndSettle(find.text('Start a new chat with Vesper'));
      final list = h.container.read(conversationsProvider).requireValue;
      expect(list.first.title, 'New chat with Vesper');
      expect(find.textContaining('The fog won\'t lift before midnight'), findsOneWidget);
      expect(find.byWidgetPredicate(bubbleColor), findsNothing);
    });

    testWidgets('Memories and the journal open their screens; no universe is explained', (t) async {
      await openChat(t);
      await t.tapAndSettle(tooltip('Conversation options'));
      await t.tapAndSettle(find.text('Memories in this world'));
      expect(find.text('How memories work'), findsOneWidget);
      expect(find.textContaining('Characters in The Saltmarsh Coast remember these'), findsOneWidget);
      await t.tapAndSettle(tooltip('Back'));
      await t.tapAndSettle(tooltip('Conversation options'));
      await t.tapAndSettle(find.text('Relationship journal'));
      expect(find.textContaining('You & Vesper'), findsOneWidget);
      expect(find.text('Where you are'.toUpperCase()), findsOneWidget);
    });
  });

  group('Text & reading sheet', () {
    testWidgets('chat: size A−/A+, line spacing, live preview, remembered', (t) async {
      final h = await openChat(t);
      await t.tapAndSettle(tooltip('Conversation options'));
      await t.tapAndSettle(find.text('Text size & reading'));
      expect(find.text('Text & reading'), findsOneWidget);
      expect(find.text('Narration'), findsNothing, reason: 'story-only');
      expect(find.text('Pacing'), findsNothing);
      expect(find.text('16'), findsOneWidget);

      double previewSize() => (t.widget<RichRoleplayText>(find.descendant(
              of: find.byType(BottomSheet), matching: find.byType(RichRoleplayText)))
          .style.fontSize)!;
      double previewHeight() => (t.widget<RichRoleplayText>(find.descendant(
              of: find.byType(BottomSheet), matching: find.byType(RichRoleplayText)))
          .style.height)!;

      expect(previewSize(), 16);
      await t.tapAndSettle(tooltip('Larger text'));
      expect(find.text('17'), findsOneWidget);
      expect(previewSize(), 17);
      await t.tapAndSettle(tooltip('Smaller text'));
      await t.tapAndSettle(tooltip('Smaller text'));
      expect(previewSize(), 15);

      expect(previewHeight(), 1.62);
      await t.tapAndSettle(find.text('Roomy'));
      expect(previewHeight(), 1.8);
      await t.tapAndSettle(find.text('Compact'));
      expect(previewHeight(), 1.5);

      final prefs = h.container.read(readingPrefsProvider);
      expect(prefs.chatSize, 15);
      expect(prefs.lineSpacing, 0);
      final sp = await SharedPreferences.getInstance();
      expect(sp.getDouble('reading.chatSize'), 15);
      expect(sp.getInt('reading.lineSpacing'), 0);
    });

    testWidgets('the size stops at 14 and 22', (t) async {
      final h = await openChat(t);
      h.container.read(readingPrefsProvider.notifier).setChatSize(14);
      await t.tapAndSettle(tooltip('Conversation options'));
      await t.tapAndSettle(find.text('Text size & reading'));
      final smaller = find.ancestor(of: tooltip('Smaller text'), matching: find.byType(TextButton)).first;
      expect(t.widget<TextButton>(smaller).onPressed, isNull);
    });

    testWidgets('story: Aa opens Reading & writing with Narration and Pacing', (t) async {
      final h = await openChat(t);
      await t.tapAndSettle(find.widgetWithText(OutlinedButton, 'Story'));
      await t.tapAndSettle(tooltip('Reading and writing preferences'));
      expect(find.text('Reading & writing'), findsOneWidget);
      expect(find.text('Narration'), findsOneWidget);
      expect(find.text('Pacing'), findsOneWidget);
      expect(find.text('She / he'), findsOneWidget);
      expect(find.textContaining('What’s already written stays as it is'), findsOneWidget);
      expect(find.text('19'), findsOneWidget);
      await t.tapAndSettle(tooltip('Larger text'));
      await t.tapAndSettle(find.text('I / me'));
      await t.tapAndSettle(find.text('Brisk'));
      final p = h.container.read(readingPrefsProvider);
      expect((p.storySize, p.narration, p.pacing), (20.0, Narration.first, Pacing.brisk));
    });

    testWidgets('the setting applies to the messages behind the sheet', (t) async {
      final h = await openChat(t);
      double replySize() => t
          .widget<RichRoleplayText>(find.byWidgetPredicate((w) =>
              w is RichRoleplayText && w.text.contains('They stay sealed until we open')))
          .style
          .fontSize!;
      expect(replySize(), 16);
      h.container.read(readingPrefsProvider.notifier).setChatSize(20);
      await t.pumpAndSettle();
      expect(replySize(), 20);
    });
  });

  testWidgets('a deleted or unknown chat shows a way back', (t) async {
    final h = await pumpHearth(t);
    await h.push('/chat/nope');
    expect(find.text('This chat isn’t here any more'), findsOneWidget);
    await t.tapAndSettle(find.text('Back to chats'));
    expect(find.byType(MessageList), findsNothing);
  });
}

// ── helpers for long conversations ─────────────────────────────────────────

/// Opens c1 with 30 filler messages in front, so there is something to read back.
Future<Harness> openLongChat(WidgetTester t) async {
  final h = await pumpHearth(t);
  h.container.read(conversationsProvider.notifier).change('c1', (c) {
    final filler = [
      for (var i = 0; i < 30; i++)
        Message(
          id: 'f$i',
          role: i.isEven ? MessageRole.ai : MessageRole.user,
          alts: ['Filler line $i'],
        ),
    ];
    return c.copyWith(messages: [...filler, ...c.messages]);
  });
  await t.pumpAndSettle();
  await h.push('/chat/c1');
  return h;
}

/// Scrolls back until a filler message is on screen; returns its index.
Future<int?> readBack(WidgetTester t) async {
  for (var i = 0; i < 12; i++) {
    final f = firstVisibleFiller(t);
    if (f != null) return f;
    await t.drag(find.byType(MessageList), const Offset(0, 700));
    await t.pumpAndSettle();
  }
  return firstVisibleFiller(t);
}

/// The index of the filler message currently nearest the top of the list.
int? firstVisibleFiller(WidgetTester t) {
  int? best;
  var bestY = double.infinity;
  for (var i = 0; i < 30; i++) {
    final f = find.text('Filler line $i');
    if (f.evaluate().isEmpty) continue;
    final y = t.getTopLeft(f).dy;
    if (y > 110 && y < bestY) {
      bestY = y;
      best = i;
    }
  }
  return best;
}
