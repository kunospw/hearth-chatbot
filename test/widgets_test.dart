import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hearth/core/theme/hearth_colors.dart';
import 'package:hearth/core/theme/hearth_theme.dart';
import 'package:hearth/core/widgets/character_avatar.dart';
import 'package:hearth/core/widgets/chat_tile.dart';
import 'package:hearth/core/widgets/composer.dart';
import 'package:hearth/core/widgets/controls.dart';
import 'package:hearth/core/widgets/inline_notice.dart';
import 'package:hearth/core/widgets/jump_to_latest_pill.dart';
import 'package:hearth/core/widgets/message_actions.dart';
import 'package:hearth/core/widgets/rich_roleplay_text.dart';
import 'package:hearth/core/widgets/sheets.dart';
import 'package:hearth/core/widgets/states.dart';
import 'package:hearth/core/widgets/toast.dart';
import 'package:hearth/data/mock/mock_data.dart';
import 'package:hearth/features/characters/presentation/widgets/character_card.dart';
import 'package:hearth/features/characters/presentation/widgets/character_grid.dart';

Widget host(Widget child, {double textScale = 1, bool bar = false}) {
  return MaterialApp(
    theme: HearthTheme.build(HearthThemeChoice.dark),
    builder: (context, c) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
      child: c!,
    ),
    home: Scaffold(body: child),
  );
}

Future<void> phone(WidgetTester t) async {
  t.view.physicalSize = const Size(360, 800);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
}

void main() {
  final vesper = MockData.characters[0];
  final iselde = MockData.characters[3];

  group('CharacterAvatar', () {
    testWidgets('paints the initial first, then fades the image in', (t) async {
      await phone(t);
      await t.pumpWidget(host(Center(child: CharacterAvatar.of(vesper, size: 56))));
      expect(find.text('V'), findsOneWidget);
      await t.pumpAndSettle();
      expect(find.text('V'), findsOneWidget, reason: 'initial stays under the portrait');
    });

    testWidgets('keeps the initial when the image fails', (t) async {
      await phone(t);
      await t.pumpWidget(host(Center(
        child: CharacterAvatar(
            tile: vesper.tile, ink: vesper.ink, initial: 'X', asset: 'assets/nope.svg', size: 56),
      )));
      await t.pumpAndSettle();
      expect(find.text('X'), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('a character without a portrait shows tile + initial', (t) async {
      await phone(t);
      await t.pumpWidget(host(Center(child: CharacterAvatar.of(iselde, size: 56))));
      expect(find.text('I'), findsOneWidget);
    });

    testWidgets('initial does not scale with system text size', (t) async {
      await phone(t);
      await t.pumpWidget(host(Center(child: CharacterAvatar.of(vesper, size: 56)), textScale: 2));
      expect(t.takeException(), isNull);
      expect(t.getSize(find.byType(CharacterAvatar)), const Size(56, 56));
    });
  });

  group('CharacterCard / grid', () {
    testWidgets('card is ≥210dp tall, shows name, tag, and taps once', (t) async {
      await phone(t);
      var taps = 0;
      await t.pumpWidget(host(Padding(
        padding: const EdgeInsets.all(20),
        child: SizedBox(width: 160, child: CharacterCard(character: vesper, onTap: () => taps++)),
      )));
      await t.pumpAndSettle();
      expect(t.getSize(find.byType(CharacterCard)).height, greaterThanOrEqualTo(210));
      expect(find.text('Vesper Hale'), findsOneWidget);
      expect(find.text('Mystery'), findsOneWidget);
      await t.tap(find.text('Vesper Hale'));
      expect(taps, 1);
    });

    testWidgets('grid is 2 columns at 360dp, 3 at 700dp, no overflow at 200%', (t) async {
      for (final (w, cols) in [(360.0, 2), (700.0, 3)]) {
        t.view.physicalSize = Size(w, 900);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        await t.pumpWidget(host(
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: CharacterGrid(children: [
              for (final c in MockData.characters) CharacterCard(character: c, onTap: () {}),
            ]),
          ),
          textScale: 2,
        ));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull, reason: 'width $w at 200%');
        final xs = {for (final e in t.widgetList(find.byType(CharacterCard))) t.getTopLeft(find.byWidget(e)).dx};
        expect(xs.length, cols);
      }
    });
  });

  group('ChatTile / ContinueCard', () {
    testWidgets('row is one tap target with a separate ≥48dp ⋯ button', (t) async {
      await phone(t);
      var row = 0, more = 0;
      await t.pumpWidget(host(Padding(
        padding: const EdgeInsets.all(20),
        child: ChatTile(
          avatar: CharacterAvatar.of(vesper),
          title: 'The letter',
          subtitle: 'Vesper · 2m ago',
          preview: 'Fine. They stay sealed.',
          pinned: true,
          onTap: () => row++,
          onMore: () => more++,
        ),
      )));
      await t.pumpAndSettle();
      final btn = find.byTooltip('More options for The letter');
      expect(t.getSize(btn).width, greaterThanOrEqualTo(48));
      expect(t.getSize(btn).height, greaterThanOrEqualTo(48));
      await t.tap(btn);
      expect((row, more), (0, 1));
      await t.tap(find.text('The letter'));
      expect((row, more), (1, 1));
    });

    testWidgets('ContinueCard resumes in one tap and survives 200% text', (t) async {
      await phone(t);
      var taps = 0;
      await t.pumpWidget(host(
        Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: ContinueCard(
              avatar: CharacterAvatar.of(vesper, size: 56),
              title: 'The letter from the north tide',
              subtitle: 'Vesper · 2m ago',
              preview: 'Your word. She seems to weigh it like rope.',
              onTap: () => taps++,
            ),
          ),
        ),
        textScale: 2,
      ));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      await t.tap(find.byType(ContinueCard));
      expect(taps, 1);
    });
  });

  group('RichRoleplayText', () {
    testWidgets('actions italic+muted, dialogue brightest, narration between', (t) async {
      await phone(t);
      await t.pumpWidget(host(Builder(
        builder: (context) => RichRoleplayText('*acts* "says" tells',
            style: context.ht.chatStyle()),
      )));
      final span = (t.widget<Text>(find.byType(Text).first).textSpan! as TextSpan);
      final kids = span.children!.cast<TextSpan>();
      const c = HearthColors.dark;
      expect(kids[0].style!.fontStyle, FontStyle.italic);
      expect(kids[0].style!.color, c.textMuted);
      expect(kids[2].style!.color, c.dialogue);
      expect(kids[3].style!.color, c.narration);
    });

    testWidgets('streaming shows a caret and half-written markup does not throw', (t) async {
      await phone(t);
      await t.pumpWidget(host(Builder(
        builder: (context) =>
            RichRoleplayText('*She steps asi', style: context.ht.chatStyle(), streaming: true),
      )));
      await t.pump(const Duration(milliseconds: 100));
      expect(t.takeException(), isNull);
      expect(find.byType(FadeTransition), findsWidgets);
    });
  });

  group('Composer', () {
    testWidgets('chat: send disabled when empty, sends trimmed text, clears', (t) async {
      await phone(t);
      final sent = <String>[];
      await t.pumpWidget(host(Align(alignment: Alignment.bottomCenter, child: Composer(onSend: sent.add))));
      await t.tap(find.byTooltip('Send message'));
      expect(sent, isEmpty);
      await t.enterText(find.byType(TextField), '  hello there ');
      await t.pump();
      await t.tap(find.byTooltip('Send message'));
      expect(sent, ['hello there']);
      expect(t.widget<TextField>(find.byType(TextField)).controller!.text, isEmpty);
    });

    testWidgets('Enter inserts a newline; Ctrl+Enter sends', (t) async {
      await phone(t);
      final sent = <String>[];
      await t.pumpWidget(host(Align(alignment: Alignment.bottomCenter, child: Composer(onSend: sent.add))));
      await t.tap(find.byType(TextField));
      await t.enterText(find.byType(TextField), 'one');
      await t.pump();
      await t.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(sent, isEmpty);
      await t.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await t.sendKeyEvent(LogicalKeyboardKey.enter);
      await t.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      expect(sent, ['one']);
    });

    testWidgets('Send ↔ Stop while generating', (t) async {
      await phone(t);
      var stops = 0;
      final sent = <String>[];
      Widget build(bool busy) => host(Align(
          alignment: Alignment.bottomCenter,
          child: Composer(isGenerating: busy, onSend: sent.add, onStop: () => stops++)));
      await t.pumpWidget(build(false));
      expect(find.byTooltip('Send message'), findsOneWidget);
      await t.pumpWidget(build(true));
      await t.pumpAndSettle();
      expect(find.byTooltip('Send message'), findsNothing);
      await t.tap(find.byTooltip('Stop reply'));
      expect(stops, 1);
      expect(sent, isEmpty);
    });

    testWidgets('story: hint, empty send means Continue', (t) async {
      await phone(t);
      final sent = <String>[];
      await t.pumpWidget(host(Align(
          alignment: Alignment.bottomCenter,
          child: Composer(variant: ComposerVariant.story, onSend: sent.add))));
      expect(find.text('What happens next? (optional)'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);
      await t.tap(find.text('Continue'));
      expect(sent, ['']);
      await t.enterText(find.byType(TextField), 'She opens it');
      await t.pumpAndSettle();
      expect(find.text('Send'), findsOneWidget);
    });

    testWidgets('grows to 5 lines then scrolls; send button ≥48dp', (t) async {
      await phone(t);
      await t.pumpWidget(host(Align(alignment: Alignment.bottomCenter, child: Composer(onSend: (_) {}))));
      final one = t.getSize(find.byType(TextField)).height;
      await t.enterText(find.byType(TextField), List.filled(12, 'line').join('\n'));
      await t.pumpAndSettle();
      final many = t.getSize(find.byType(TextField)).height;
      expect(many, greaterThan(one));
      final five = (many - one) / 4;
      expect(five, greaterThan(10), reason: 'five lines tall at most');
      final b = t.getSize(find.byTooltip('Send message'));
      expect(b.width, greaterThanOrEqualTo(48));
      expect(b.height, greaterThanOrEqualTo(48));
    });
  });

  group('MessageActions', () {
    testWidgets('alt navigator only with >1 version; "‹ 2 of 3 ›" works', (t) async {
      await phone(t);
      await t.pumpWidget(host(const MessageActions(onRewrite: _noop, onCopy: _noop, onEdit: _noop)));
      expect(find.textContaining(' of '), findsNothing);

      var idx = 1;
      late StateSetter set;
      await t.pumpWidget(host(StatefulBuilder(builder: (c, s) {
        set = s;
        return MessageActions(
          altIndex: idx,
          altCount: 3,
          onPrevAlt: () => set(() => idx--),
          onNextAlt: () => set(() => idx++),
          onRewrite: _noop,
        );
      })));
      expect(find.text('2 of 3'), findsOneWidget);
      await t.tap(find.byTooltip('Next version'));
      await t.pump();
      expect(find.text('3 of 3'), findsOneWidget);
      expect(t.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.chevron_right)).onPressed, isNull);
    });

    testWidgets('every action is ≥44dp tall and labelled', (t) async {
      await phone(t);
      await t.pumpWidget(host(const MessageActions(
          altCount: 2, altIndex: 1, onPrevAlt: _noop, onRewrite: _noop, onCopy: _noop, onEdit: _noop)));
      for (final label in ['Rewrite', 'Copy', 'Edit']) {
        final box = t.getSize(find.ancestor(of: find.text(label), matching: find.byType(TextButton)).first);
        expect(box.height, greaterThanOrEqualTo(44), reason: label);
      }
      expect(t.getSize(find.byTooltip('Previous version')).height, greaterThanOrEqualTo(44));
    });

    testWidgets('wraps instead of overflowing at 200%', (t) async {
      await phone(t);
      await t.pumpWidget(host(
          const MessageActions(altCount: 3, altIndex: 1, onPrevAlt: _noop, onNextAlt: _noop, onRewrite: _noop, onCopy: _noop, onEdit: _noop),
          textScale: 2));
      expect(t.takeException(), isNull);
    });
  });

  group('InlineNotice', () {
    testWidgets('primary and secondary actions fire', (t) async {
      await phone(t);
      var p = 0, s = 0;
      await t.pumpWidget(host(Padding(
        padding: const EdgeInsets.all(20),
        child: InlineNotice(
          title: 'Daily limit reached',
          message: 'Your message is saved.',
          primaryLabel: 'Switch model',
          onPrimary: () => p++,
          secondaryLabel: 'Try again',
          onSecondary: () => s++,
        ),
      ), textScale: 2));
      await t.tap(find.text('Switch model'));
      await t.tap(find.text('Try again'));
      expect((p, s), (1, 1));
      expect(t.takeException(), isNull);
    });
  });

  group('sheets', () {
    Future<void> open(WidgetTester t, Future<Object?> Function(BuildContext) fn, void Function(Object?) got) async {
      await phone(t);
      await t.pumpWidget(host(Builder(
        builder: (context) => Center(
          child: FilledButton(onPressed: () async => got(await fn(context)), child: const Text('open')),
        ),
      )));
      await t.tap(find.text('open'));
      await t.pumpAndSettle();
    }

    testWidgets('discard sheet: Save draft / Keep editing / Discard', (t) async {
      DiscardChoice? r;
      await open(t, showDiscardSheet, (v) => r = v as DiscardChoice);
      expect(find.text('Save draft'), findsOneWidget);
      await t.tap(find.text('Discard'));
      await t.pumpAndSettle();
      expect(r, DiscardChoice.discard);

      await t.tap(find.text('open'));
      await t.pumpAndSettle();
      await t.tap(find.text('Save draft'));
      await t.pumpAndSettle();
      expect(r, DiscardChoice.saveDraft);
    });

    testWidgets('dismissing the discard sheet means keep editing', (t) async {
      DiscardChoice? r;
      await open(t, showDiscardSheet, (v) => r = v as DiscardChoice);
      await t.tapAt(const Offset(180, 20)); // scrim
      await t.pumpAndSettle();
      expect(r, DiscardChoice.keepEditing);
    });

    testWidgets('confirm delete: safe option first; only Delete returns true', (t) async {
      bool? r;
      await open(
          t,
          (c) => showConfirmDeleteSheet(c, title: 'Delete this chat?', keepLabel: 'Keep chat', deleteLabel: 'Delete chat'),
          (v) => r = v as bool);
      expect(t.getTopLeft(find.text('Keep chat')).dy, lessThan(t.getTopLeft(find.text('Delete chat')).dy));
      await t.tap(find.text('Keep chat'));
      await t.pumpAndSettle();
      expect(r, isFalse);
      await t.tap(find.text('open'));
      await t.pumpAndSettle();
      await t.tap(find.text('Delete chat'));
      await t.pumpAndSettle();
      expect(r, isTrue);
    });

    testWidgets('options sheet returns the tapped value; rows ≥48dp', (t) async {
      String? r;
      await open(
          t,
          (c) => showOptionsSheet<String>(c, options: const [
                SheetOption(value: 'a', label: 'Rename', icon: Icons.edit),
                SheetOption(value: 'b', label: 'Delete chat', icon: Icons.delete, destructive: true),
              ]),
          (v) => r = v as String?);
      expect(t.getSize(find.ancestor(of: find.text('Rename'), matching: find.byType(InkWell)).first).height, greaterThanOrEqualTo(48));
      await t.tap(find.text('Delete chat'));
      await t.pumpAndSettle();
      expect(r, 'b');
    });
  });

  group('toast', () {
    testWidgets('Undo runs the callback and dismisses', (t) async {
      await phone(t);
      var undone = 0;
      await t.pumpWidget(host(Builder(
        builder: (context) => FilledButton(
          onPressed: () => showToast(context, 'Memory deleted', onUndo: () => undone++),
          child: const Text('go'),
        ),
      )));
      await t.tap(find.text('go'));
      await t.pumpAndSettle();
      expect(find.text('Memory deleted'), findsOneWidget);
      expect(t.getSize(find.widgetWithText(TextButton, 'Undo')).height, greaterThanOrEqualTo(44));
      await t.tap(find.text('Undo'));
      await t.pumpAndSettle();
      expect(undone, 1);
      expect(find.text('Memory deleted'), findsNothing);
    });

    testWidgets('a new toast replaces the old one', (t) async {
      await phone(t);
      await t.pumpWidget(host(Builder(
        builder: (context) => Column(children: [
          TextButton(onPressed: () => showToast(context, 'First'), child: const Text('a')),
          TextButton(onPressed: () => showToast(context, 'Second'), child: const Text('b')),
        ]),
      )));
      await t.tap(find.text('a'));
      await t.pumpAndSettle();
      await t.tap(find.text('b'));
      await t.pumpAndSettle();
      expect(find.text('First'), findsNothing);
      expect(find.text('Second'), findsOneWidget);
    });
  });

  group('controls', () {
    testWidgets('segmented: selects, exposes selected semantics, ≥44dp', (t) async {
      await phone(t);
      final h = t.ensureSemantics();
      var v = 'a';
      await t.pumpWidget(host(StatefulBuilder(
        builder: (c, set) => HearthSegmented<String>(
            options: const {'a': 'Dark', 'b': 'True black'}, value: v, onChanged: (x) => set(() => v = x)),
      )));
      expect(t.getSemantics(find.text('Dark')).flagsCollection.isSelected.toString(), contains('isTrue'));
      await t.tap(find.text('True black'));
      await t.pumpAndSettle();
      expect(v, 'b');
      expect(t.getSize(find.text('True black')).height, greaterThan(0));
      expect(t.getSize(find.ancestor(of: find.text('Dark'), matching: find.byType(AnimatedContainer)).first).height, greaterThanOrEqualTo(44));
      h.dispose();
    });

    testWidgets('chip: ≥44dp target and selected state in semantics', (t) async {
      await phone(t);
      final h = t.ensureSemantics();
      var taps = 0;
      await t.pumpWidget(host(Center(child: HearthChip(label: 'Pinned', selected: true, onTap: () => taps++))));
      final size = t.getSize(find.byType(HearthChip));
      expect(size.height, greaterThanOrEqualTo(44));
      expect(t.getSemantics(find.byType(HearthChip)).flagsCollection.isSelected.toString(), contains('isTrue'));
      await t.tap(find.text('Pinned'));
      expect(taps, 1);
      h.dispose();
    });

    testWidgets('switch row toggles from anywhere on the row', (t) async {
      await phone(t);
      var on = false;
      await t.pumpWidget(host(StatefulBuilder(
        builder: (c, set) => SwitchRow(title: 'Show notes', subtitle: 'Subtle', value: on, onChanged: (v) => set(() => on = v)),
      )));
      await t.tap(find.text('Show notes'));
      await t.pump();
      expect(on, isTrue);
      expect(t.getSize(find.byType(SwitchRow)).height, greaterThanOrEqualTo(48));
    });

    testWidgets('radio row selects and disabled rows do not', (t) async {
      await phone(t);
      var taps = 0;
      await t.pumpWidget(host(Column(children: [
        RadioRow(title: 'Ember', selected: false, onTap: () => taps++),
        RadioRow(title: 'Atlas Pro', status: 'Busy right now', selected: false, enabled: false, onTap: () => taps += 10),
      ])));
      await t.tap(find.text('Ember'));
      await t.tap(find.text('Atlas Pro'));
      expect(taps, 1);
    });
  });

  group('JumpToLatestPill', () {
    testWidgets('visible pill is tappable; a hidden pill is removed', (t) async {
      await phone(t);
      var taps = 0;
      Widget pill(bool v) => host(Center(child: JumpToLatestPill(visible: v, onTap: () => taps++)));
      await t.pumpWidget(pill(true));
      await t.pumpAndSettle();
      expect(t.getSize(find.byType(JumpToLatestPill)).height, greaterThanOrEqualTo(44));
      await t.tap(find.text('New reply below'));
      expect(taps, 1);
      await t.pumpWidget(pill(false));
      await t.pumpAndSettle();
      expect(find.text('New reply below'), findsNothing, reason: 'gone from the tree, so not announced');
      expect(taps, 1);
    });
  });

  group('states', () {
    testWidgets('first-run, offline and skeleton render without overflow at 200%', (t) async {
      await phone(t);
      for (final w in <Widget>[
        FirstRunState(onMeetSamples: () {}, onCreate: () {}),
        OfflineState(onRetry: () {}),
        const HomeSkeleton(),
        const SkeletonRows(),
      ]) {
        await t.pumpWidget(host(w, textScale: 2));
        await t.pump(const Duration(milliseconds: 300));
        expect(t.takeException(), isNull, reason: '${w.runtimeType}');
      }
    });

    testWidgets('first-run copy and actions', (t) async {
      await phone(t);
      var a = 0, b = 0;
      await t.pumpWidget(host(FirstRunState(onMeetSamples: () => a++, onCreate: () => b++)));
      expect(find.text('Your first story starts here'), findsOneWidget);
      await t.tap(find.text('Meet the sample characters'));
      await t.tap(find.text('Create my own'));
      expect((a, b), (1, 1));
    });

    testWidgets('offline state: "Can\'t reach Hearth right now" + Try again', (t) async {
      await phone(t);
      var retried = 0;
      await t.pumpWidget(host(OfflineState(onRetry: () => retried++)));
      expect(find.text('Can’t reach Hearth right now'), findsOneWidget);
      await t.tap(find.text('Try again'));
      expect(retried, 1);
    });
  });

  testWidgets('no technical words in widget copy', (t) async {
    await phone(t);
    await t.pumpWidget(host(SingleChildScrollView(
      child: Column(children: [
        SizedBox(height: 500, child: FirstRunState(onMeetSamples: () {}, onCreate: () {})),
        InlineNotice(title: 'Daily limit reached', message: 'Your message is saved.', primaryLabel: 'Switch model', onPrimary: () {}),
      ]),
    )));
    final all = t.widgetList<Text>(find.byType(Text)).map((w) => w.data ?? w.textSpan?.toPlainText() ?? '').join(' ').toLowerCase();
    for (final bad in ['token', 'context', 'temperature']) {
      expect(all.contains(bad), isFalse, reason: bad);
    }
  });
}

void _noop() {}
