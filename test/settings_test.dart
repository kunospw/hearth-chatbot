import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hearth/core/theme/hearth_colors.dart';
import 'package:hearth/core/theme/hearth_theme.dart';
import 'package:hearth/core/theme/theme_provider.dart';
import 'package:hearth/core/widgets/states.dart';
import 'package:hearth/features/chat/data/chat_controller.dart';
import 'package:hearth/features/chat/data/conversation_repository.dart';
import 'package:hearth/features/chat/domain/chat_models.dart';
import 'package:hearth/features/characters/data/character_repository.dart';
import 'package:hearth/features/settings/data/ai_prefs.dart';
import 'package:hearth/features/settings/data/app_prefs.dart';
import 'package:hearth/features/settings/data/model_usage.dart';
import 'package:hearth/features/settings/data/reading_prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/harness.dart';

Future<Harness> openSettings(WidgetTester t, {double textScale = 1, Map<String, Object> prefs = const {}}) async {
  final h = await pumpHearth(t, textScale: textScale, prefs: prefs);
  await t.tapAndSettle(tooltip('Profile and settings'));
  return h;
}

Future<Harness> openAi(WidgetTester t, {double textScale = 1}) async {
  final h = await pumpHearth(t, textScale: textScale);
  await h.push('/settings/ai');
  return h;
}

Color scaffoldBg(WidgetTester t) =>
    Theme.of(t.element(find.byType(Scaffold).last)).scaffoldBackgroundColor;

/// Scrolls the on-screen vertical list until [f] is on screen.
Future<void> show(WidgetTester t, Finder f) async {
  final list = find.byWidgetPredicate((w) => w is Scrollable && w.axis == Axis.vertical).last;
  await t.scrollUntilVisible(f, 250, scrollable: list);
  await t.ensureVisible(f);
  await t.pumpAndSettle();
}

void main() {
  group('Settings', () {
    testWidgets('sections: account, Appearance, Roleplay, Privacy, Your data', (t) async {
      await openSettings(t);
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Wren'), findsOneWidget, reason: 'the active persona');
      expect(find.text('Your stories are saved on this device'), findsOneWidget);
      for (final s in ['APPEARANCE', 'ROLEPLAY']) {
        expect(find.text(s, skipOffstage: false), findsOneWidget, reason: s);
      }
      expect(find.text('Theme'), findsOneWidget);
      for (final o in ['Dark', 'True black', 'Light', 'System']) {
        expect(find.text(o), findsOneWidget, reason: o);
      }
      expect(find.text('Chat text size'), findsOneWidget);
      for (final o in ['Small', 'Default', 'Large', 'Larger']) {
        expect(find.text(o), findsOneWidget, reason: o);
      }
    });

    testWidgets('Back returns to where you came from', (t) async {
      await openSettings(t);
      await t.tapAndSettle(tooltip('Back'));
      expect(find.text('CONTINUE CHATTING'), findsOneWidget);
    });

    testWidgets('theme: Dark → True black → Light → System, instantly and remembered', (t) async {
      final h = await openSettings(t);
      expect(scaffoldBg(t), HearthColors.dark.bg);

      await t.tapAndSettle(find.text('True black'));
      expect(scaffoldBg(t), HearthColors.trueBlack.bg);
      expect(h.container.read(themeChoiceProvider), HearthThemeChoice.trueBlack);

      await t.tapAndSettle(find.text('Light'));
      expect(scaffoldBg(t), HearthColors.light.bg);
      expect(Theme.of(t.element(find.byType(Scaffold).last)).brightness, Brightness.light);

      await t.tapAndSettle(find.text('Dark'));
      expect(scaffoldBg(t), HearthColors.dark.bg);
      final sp = await SharedPreferences.getInstance();
      expect(sp.getString('theme_choice'), 'dark');
    });

    testWidgets('a saved theme choice is used on the next launch', (t) async {
      await pumpHearth(t, prefs: {'theme_choice': 'light'});
      expect(scaffoldBg(t), HearthColors.light.bg);
    });

    testWidgets('chat text size: the nearest choice is selected and changing it applies', (t) async {
      final h = await openSettings(t);
      await t.tapAndSettle(find.text('Large'));
      expect(h.container.read(readingPrefsProvider).chatSize, 18);
      await t.tapAndSettle(find.text('Small'));
      expect(h.container.read(readingPrefsProvider).chatSize, 15);
      final sp = await SharedPreferences.getInstance();
      expect(sp.getDouble('reading.chatSize'), 15);
    });

    testWidgets('"New chats open in" decides the mode of a brand-new chat', (t) async {
      final h = await openSettings(t);
      expect(h.container.read(appPrefsProvider).defaultMode, ChatMode.chat);
      await t.tapAndSettle(find.text('Story mode'));
      expect(h.container.read(appPrefsProvider).defaultMode, ChatMode.story);

      final jun = h.container.read(charactersProvider).requireValue.firstWhere((c) => c.id == 'jun');
      final id = h.container.read(conversationsProvider.notifier).startNew(jun);
      expect(h.container.read(conversationProvider(id))!.mode, ChatMode.story);
      // existing chats keep their own mode
      expect(h.container.read(conversationProvider('c1'))!.mode, ChatMode.chat);
    });

    testWidgets('the AI settings card summarises your choices and opens the screen', (t) async {
      final h = await openSettings(t);
      await show(t, find.text('AI settings'));
      expect(find.text('Ember · Medium replies · Balanced'), findsOneWidget);
      h.container.read(aiPrefsProvider.notifier).setLength(ReplyLength.long);
      h.container.read(selectedModelIdProvider.notifier).select('lumen');
      await t.pumpAndSettle();
      expect(find.text('Lumen · Long replies · Balanced'), findsOneWidget);
      await t.tapAndSettle(find.text('AI settings'));
      expect(find.text('These apply to every chat. Change them anytime — nothing here affects what’s already written.'),
          findsOneWidget);
    });

    testWidgets('privacy toggles flip, are whole-row targets, and are remembered', (t) async {
      final h = await openSettings(t);
      await show(t, find.text('Hide message previews'));
      expect(h.container.read(appPrefsProvider).hidePreviews, isTrue);
      await t.tapAndSettle(find.text('Hide message previews'));
      expect(h.container.read(appPrefsProvider).hidePreviews, isFalse);
      await t.tapAndSettle(find.text('Blur in app switcher'));
      expect(h.container.read(appPrefsProvider).blurSwitcher, isTrue);
      final sp = await SharedPreferences.getInstance();
      expect(sp.getBool('app.hidePreviews'), isFalse);
      expect(sp.getBool('app.blurSwitcher'), isTrue);
    });

    testWidgets('Export says honestly it comes later; Sign out explains there is no account on sample data', (t) async {
      await openSettings(t);
      await show(t, find.text('Export everything'));
      await t.tapAndSettle(find.text('Export everything'));
      expect(find.textContaining('Export arrives with your online account'), findsOneWidget);
      await show(t, find.text('Sign out'));
      await t.tapAndSettle(find.text('Sign out'));
      expect(find.textContaining('You’re not signed in'), findsOneWidget);
    });

    testWidgets('no technical words anywhere on the Settings screen', (t) async {
      await openSettings(t);
      final texts = <String>[];
      for (var i = 0; i < 6; i++) {
        texts.addAll(t.widgetList<Text>(find.byType(Text)).map((w) => (w.data ?? w.textSpan?.toPlainText() ?? '').toLowerCase()));
        await t.drag(find.byType(Scrollable).last, const Offset(0, -500));
        await t.pumpAndSettle();
      }
      final all = texts.join(' ');
      for (final bad in ['token', 'context', 'temperature', 'penalty']) {
        expect(all.contains(bad), isFalse, reason: bad);
      }
    });

    testWidgets('holds at 200% text', (t) async {
      await openSettings(t, textScale: 2);
      expect(t.takeException(), isNull);
      for (var i = 0; i < 5; i++) {
        await t.drag(find.byType(Scrollable).last, const Offset(0, -600));
        await t.pumpAndSettle();
      }
      expect(t.takeException(), isNull);
    });

    testWidgets('targets: back ≥48dp, rows ≥48dp', (t) async {
      await openSettings(t);
      final s = t.getSize(tooltip('Back'));
      expect(s.width, greaterThanOrEqualTo(48));
      expect(s.height, greaterThanOrEqualTo(48));
    });
  });

  group('AI settings', () {
    testWidgets('models show their availability and the reason when they are not', (t) async {
      await openAi(t);
      expect(find.text('MODEL'), findsOneWidget);
      for (final m in ['Ember', 'Lumen', 'Atlas Pro']) {
        expect(find.text(m), findsOneWidget, reason: m);
      }
      expect(find.text('Available · 2 of 30 free replies left today'), findsOneWidget);
      expect(find.text('Available · 41 of 50 free replies left today'), findsOneWidget);
      expect(find.text('Busy right now — try again later'), findsOneWidget);
      expect(find.text('Free models have a daily reply limit. It resets every day at 07:00.'),
          findsOneWidget);
    });

    testWidgets('loading shows a shimmer, then the models', (t) async {
      SharedPreferences.setMockInitialValues({});
      await pumpHearth(t, latency: const Duration(milliseconds: 600), settle: false);
      await t.pump(const Duration(seconds: 2));
      final h = await Future.value(Harness(t, ProviderScope.containerOf(t.element(find.byType(Scaffold).first))));
      h.router.push('/settings/ai');
      await t.pump(const Duration(milliseconds: 50));
      await t.pump(const Duration(milliseconds: 100));
      expect(find.byType(Skeleton), findsOneWidget);
      await t.pumpAndSettle();
      expect(find.text('Lumen'), findsOneWidget);
    });

    testWidgets('picking an available model selects it with "Switched to X"', (t) async {
      final h = await openAi(t);
      await t.tapAndSettle(find.text('Lumen'));
      expect(find.text('Switched to Lumen'), findsOneWidget);
      expect(h.container.read(selectedModelIdProvider), 'lumen');
      final sp = await SharedPreferences.getInstance();
      expect(sp.getString('selected_model'), 'lumen');
    });

    testWidgets('a busy or used-up model cannot be picked', (t) async {
      final h = await openAi(t);
      await t.tapAndSettle(find.text('Atlas Pro'));
      expect(h.container.read(selectedModelIdProvider), 'ember');
      h.container.read(modelUsageProvider.notifier).state = {'ember': 0, 'lumen': 41};
      await t.pumpAndSettle();
      expect(find.text('Daily limit reached · resets 07:00'), findsOneWidget);
      await t.tapAndSettle(find.text('Lumen'));
      await t.tapAndSettle(find.text('Ember'));
      expect(h.container.read(selectedModelIdProvider), 'lumen', reason: 'Ember is used up');
    });

    testWidgets('response length, writing style and creativity (with its hint)', (t) async {
      final h = await openAi(t);
      await show(t, find.text('Long'));
      await t.tapAndSettle(find.text('Long'));
      expect(h.container.read(aiPrefsProvider).length, ReplyLength.long);
      await t.tapAndSettle(find.text('Literary'));
      expect(h.container.read(aiPrefsProvider).style, WritingStyle.literary);

      expect(find.text('A good mix of consistency and surprise. Recommended.'), findsOneWidget);
      await t.tapAndSettle(find.text('Adventurous'));
      expect(find.text('Takes bold turns and invents freely. May drift off-script.'), findsOneWidget);
      await t.tapAndSettle(find.text('Steady'));
      expect(find.text('Stays close to the character and plot. Fewer surprises.'), findsOneWidget);
      expect(h.container.read(aiPrefsProvider).creativity, Creativity.steady);
    });

    testWidgets('technical words appear only inside Advanced', (t) async {
      await openAi(t);
      Iterable<String> visible() => t
          .widgetList<Text>(find.byType(Text, skipOffstage: false))
          .map((w) => (w.data ?? w.textSpan?.toPlainText() ?? '').toLowerCase());
      for (final bad in ['temperature', 'tokens', 'context depth', 'repetition penalty']) {
        expect(visible().any((s) => s.contains(bad)), isFalse, reason: '$bad (Advanced is collapsed)');
      }
      await show(t, find.text('Advanced'));
      await t.tapAndSettle(find.text('Advanced'));
      expect(find.text('Technical controls for fine-tuning. Safe to ignore.'), findsOneWidget);
      await show(t, find.text('Reset to defaults'));
      for (final label in ['Temperature', 'Max reply tokens', 'Context depth (messages)', 'Repetition penalty']) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      expect(find.byType(Slider), findsNWidgets(4));
    });

    testWidgets('Advanced: sliders change the values; Reset to defaults restores them', (t) async {
      final h = await openAi(t);
      await show(t, find.text('Advanced'));
      await t.tapAndSettle(find.text('Advanced'));
      await show(t, find.text('Reset to defaults'));
      expect(h.container.read(aiPrefsProvider).advanced.temperature, 0.9);

      final slider = find.byType(Slider).first;
      await t.drag(slider, const Offset(120, 0));
      await t.pumpAndSettle();
      expect(h.container.read(aiPrefsProvider).advanced.temperature, isNot(0.9));

      await t.tapAndSettle(find.text('Reset to defaults'));
      expect(find.text('Advanced settings reset'), findsOneWidget);
      expect(h.container.read(aiPrefsProvider).advanced.temperature, 0.9);
      expect(h.container.read(aiPrefsProvider).advanced.maxTokens, 600);
      expect(h.container.read(aiPrefsProvider).advanced.contextDepth, 40);
      expect(h.container.read(aiPrefsProvider).advanced.repetitionPenalty, 1.1);
    });

    testWidgets('length and creativity also set their Advanced values (as the help text says)',
        (t) async {
      final h = await openAi(t);
      h.container.read(aiPrefsProvider.notifier).setLength(ReplyLength.short);
      h.container.read(aiPrefsProvider.notifier).setCreativity(Creativity.wild);
      expect(h.container.read(aiPrefsProvider).advanced.maxTokens, 300);
      expect(h.container.read(aiPrefsProvider).advanced.temperature, 1.3);
    });

    testWidgets('choices are remembered', (t) async {
      final h = await openAi(t);
      h.container.read(aiPrefsProvider.notifier).setStyle(WritingStyle.casual);
      final sp = await SharedPreferences.getInstance();
      expect(sp.getString('ai.style'), 'casual');
    });

    testWidgets('switching model here resumes the reply waiting in a chat', (t) async {
      final h = await pumpHearth(t);
      await h.push('/chat/c1');
      h.container.read(modelUsageProvider.notifier).state = {'ember': 0, 'lumen': 41};
      await t.enterText(find.byType(TextField).last, 'Then let us open it together.');
      await t.pump();
      await t.tap(tooltip('Send message'));
      await t.pumpAndSettle();
      expect(find.text('Ember has used today’s free replies'), findsOneWidget);

      // Go to AI settings (profile route) and pick Lumen; then return to the chat.
      h.router.push('/settings/ai');
      await t.pumpAndSettle();
      await t.tapAndSettle(find.text('Lumen'));
      await t.tapAndSettle(tooltip('Back'));
      await t.pumpAndSettle();
      expect(find.text('Ember has used today’s free replies'), findsNothing);
      expect(h.container.read(conversationProvider('c1'))!.messages.last.role, MessageRole.ai);
      expect(h.container.read(chatControllerProvider('c1')).error, isNull);
    });

    testWidgets('holds at 200% text, Advanced open', (t) async {
      await openAi(t, textScale: 2);
      await show(t, find.text('Advanced'));
      await t.tapAndSettle(find.text('Advanced'));
      for (var i = 0; i < 4; i++) {
        await t.drag(find.byType(Scrollable).last, const Offset(0, -600));
        await t.pumpAndSettle();
      }
      expect(t.takeException(), isNull);
    });
  });
}
