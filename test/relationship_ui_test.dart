import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hearth/core/widgets/composer.dart';
import 'package:hearth/features/chat/presentation/message_list.dart';
import 'package:hearth/features/relationship/data/relationship_providers.dart';
import 'package:hearth/features/relationship/domain/relationship_models.dart';

import 'support/harness.dart';

Relationship relOf(Harness h, String character) =>
    h.container.read(relationshipProvider(character)).valueOrNull!;

Finder composerField() => find.descendant(
  of: find.byType(Composer),
  matching: find.byType(TextField),
);

Future<void> send(WidgetTester t, String text) async {
  await t.enterText(composerField(), text);
  await t.pump();
  await t.tap(tooltip('Send message'));
  // Let the reply stream and the engine settle.
  for (var i = 0; i < 60; i++) {
    await t.pump(const Duration(milliseconds: 60));
  }
  await t.pumpAndSettle();
}

Future<Harness> journal(
  WidgetTester t,
  String id, {
  String? entry,
  Map<String, Object> prefs = const {},
}) async {
  final h = await pumpHearth(t, prefs: prefs);
  await h.push(
    '/characters/$id/relationship${entry == null ? '' : '?entry=$entry'}',
  );
  return h;
}

Finder section(String label) => find.text(label.toUpperCase());

void main() {
  group('journey G: why did that change?', () {
    testWidgets('Why? under a message opens the journal on that entry: 1 tap', (
      t,
    ) async {
      final h = await pumpHearth(t);
      await h.push('/chat/c1');
      final why = find.text('Trust grew a little · Why?');
      expect(why, findsOneWidget);
      expect(
        t
            .getSize(
              find.ancestor(of: why, matching: find.byType(InkWell)).first,
            )
            .height,
        greaterThanOrEqualTo(44),
      );
      await t.tapAndSettle(why);
      expect(find.text('Relationship journal'), findsOneWidget);
      expect(find.text('Why it changed'), findsOneWidget);
      expect(find.text('Undo this change'), findsOneWidget);
      expect(find.text('You gave your word about the letters'), findsOneWidget);
    });

    testWidgets(
      'notes can be Hidden in the journal; the journal still records',
      (t) async {
        final h = await pumpHearth(t, prefs: {'app.relNotes': 'hidden'});
        await h.push('/chat/c1');
        expect(find.textContaining('Why?'), findsNothing);
        await h.push('/characters/vesper/relationship');
        expect(
          find.text('You gave your word about the letters'),
          findsOneWidget,
        );
      },
    );

    testWidgets('Story mode shows the ornament, not numbers', (t) async {
      final h = await pumpHearth(t);
      await h.push('/chat/c1');
      await t.tapAndSettle(find.widgetWithText(OutlinedButton, 'Story'));
      await t.drag(find.byType(MessageList), const Offset(0, 300));
      await t.pumpAndSettle();
      expect(
        find.text('— Your word settled something between you. —'),
        findsOneWidget,
      );
      expect(find.textContaining('Trust'), findsNothing);
    });
  });

  group('journal', () {
    testWidgets('header, stage, meters and settings', (t) async {
      await journal(t, 'vesper');
      expect(find.text('Relationship journal'), findsOneWidget);
      expect(find.text('You & Vesper · The Saltmarsh Coast'), findsOneWidget);
      expect(section('Where you are'), findsOneWidget);
      expect(find.text('Wary Acquaintances'), findsWidgets);
      expect(find.textContaining('Next: Reluctant Allies'), findsOneWidget);
      expect(find.text('Slow burn'), findsWidgets);
      expect(find.text('Let the story decide'), findsWidgets);
    });

    testWidgets('romance off dims attraction and says so', (t) async {
      final h = await journal(t, 'vesper');
      final scroll = find.byType(Scrollable).first;
      await t.scrollUntilVisible(
        find.text('Platonic'),
        300,
        scrollable: scroll,
      );
      await t.tapAndSettle(find.text('Platonic'));
      expect(
        find.text('Romance is off. Attraction no longer shapes the story.'),
        findsOneWidget,
      );
      expect(relOf(h, 'vesper').type, RelationType.platonic);
      expect(find.text('Not part of this relationship'), findsWidgets);
    });

    testWidgets(
      'Undo this change strikes it through, frees the value and toasts',
      (t) async {
        final h = await journal(t, 'vesper', entry: 'e5');
        final before = relOf(h, 'vesper').values.trust;
        await t.ensureVisible(find.text('Undo this change'));
        await t.pumpAndSettle();
        await t.tapAndSettle(find.text('Undo this change'));
        expect(find.text('Change undone'), findsOneWidget);
        expect(find.text('You undid this change.'), findsOneWidget);
        expect(relOf(h, 'vesper').values.trust, lessThan(before));
        expect(find.text('Undo this change'), findsNothing);
      },
    );

    testWidgets('Adjust saves a correction as a new baseline', (t) async {
      final h = await journal(t, 'vesper');
      await t.ensureVisible(find.text('Adjust'));
      await t.pumpAndSettle();
      await t.tapAndSettle(find.text('Adjust'));
      expect(find.text('Adjust the relationship'), findsOneWidget);
      await t.enterText(find.byType(TextField).last, 'We made up off-screen');
      await t.ensureVisible(find.text('Save correction'));
      await t.tapAndSettle(find.text('Save correction'));
      expect(
        find.text('Correction saved — the next reply will reflect it'),
        findsOneWidget,
      );
      expect(relOf(h, 'vesper').events.first.category, TimelineKind.correction);
    });

    testWidgets(
      'facts: add (disabled when empty), lock toggle, remove with Undo',
      (t) async {
        final h = await journal(t, 'jun');
        final scroll = find.byType(Scrollable).first;
        await t.scrollUntilVisible(find.text('Add'), 300, scrollable: scroll);
        await t.tapAndSettle(find.text('Add'));
        expect(find.text('Add an established fact'), findsOneWidget);
        final save = find.widgetWithText(FilledButton, 'Save fact');
        expect(t.widget<FilledButton>(save).onPressed, isNull);
        await t.enterText(
          find.byType(TextField).last,
          'Jun owes you a favour.',
        );
        await t.pump();
        await t.tapAndSettle(save);
        expect(
          relOf(h, 'jun').facts.any((f) => f.text == 'Jun owes you a favour.'),
          isTrue,
        );
        await t.ensureVisible(find.text('Jun owes you a favour.'));
        await t.tapAndSettle(tooltip('Remove fact').last);
        expect(find.text('Fact removed'), findsOneWidget);
        expect(
          relOf(h, 'jun').facts.any((f) => f.text == 'Jun owes you a favour.'),
          isFalse,
        );
        await t.tapAndSettle(find.text('Undo'));
        expect(
          relOf(h, 'jun').facts.any((f) => f.text == 'Jun owes you a favour.'),
          isTrue,
        );
      },
    );

    testWidgets('presets rename the stages; Edit stages saves names', (
      t,
    ) async {
      final h = await journal(t, 'jun');
      final scroll = find.byType(Scrollable).first;
      await t.scrollUntilVisible(
        find.text('Family').last,
        300,
        scrollable: scroll,
      );
      await t.tapAndSettle(find.text('Family').last);
      expect(find.text('Stages set to Family'), findsOneWidget);
      expect(relOf(h, 'jun').stages.first, 'Estranged');
      await t.ensureVisible(find.text('Edit stages'));
      await t.pumpAndSettle();
      await t.tapAndSettle(find.text('Edit stages'));
      await t.enterText(find.byType(TextField).first, 'Strangers again');
      await t.ensureVisible(find.text('Save stages'));
      await t.tapAndSettle(find.text('Save stages'));
      expect(find.text('Stages saved'), findsOneWidget);
      expect(relOf(h, 'jun').stages.first, 'Strangers again');
    });

    testWidgets('a missing character shows a way back', (t) async {
      await journal(t, 'nobody');
      expect(find.text('We can’t find this character'), findsOneWidget);
    });
  });

  group('Manual pacing', () {
    testWidgets('the story suggests, you approve', (t) async {
      final h = await pumpHearth(t);
      await h.push('/characters/jun/relationship');
      await t.scrollUntilVisible(
        find.text('Manual'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await t.tapAndSettle(find.text('Manual'));
      expect(find.textContaining('Nothing changes on its own'), findsOneWidget);
      h.router.pushReplacement('/chat/c2');
      await t.pumpAndSettle();
      await send(
        t,
        'I promise I will always keep this between us. You have my word.',
      );
      expect(relOf(h, 'jun').pending, isNotEmpty);
      final trust = relOf(h, 'jun').values.trust;
      await t.drag(find.byType(MessageList), const Offset(0, 160));
      await t.pumpAndSettle();
      expect(find.text('Suggested change · review it'), findsOneWidget);
      await t.ensureVisible(find.text('Suggested change · review it'));
      await t.pumpAndSettle();
      await t.tapAndSettle(find.text('Suggested change · review it'));
      expect(section('Waiting for your approval'), findsOneWidget);
      await t.tapAndSettle(find.text('Apply'));
      expect(find.text('Change applied'), findsOneWidget);
      expect(relOf(h, 'jun').pending, isEmpty);
      expect(relOf(h, 'jun').values.trust, greaterThan(trust));
    });
  });

  group('in the chat', () {
    testWidgets('a promise moves trust and shows a quiet note you can open', (
      t,
    ) async {
      final h = await pumpHearth(t);
      await h.push('/chat/c2');
      await h.container.read(relationshipsProvider.notifier).ensure('jun');
      final before = relOf(h, 'jun').values.trust;
      await send(t, 'I promise I will be there at dawn. You have my word.');
      expect(relOf(h, 'jun').values.trust, greaterThan(before));
      await t.drag(find.byType(MessageList), const Offset(0, 160));
      await t.pumpAndSettle();
      expect(find.textContaining('· Why?'), findsOneWidget);
      // No numbers ever appear in the chat.
      expect(find.textContaining(RegExp(r'trust \d')), findsNothing);
      await t.ensureVisible(find.textContaining('· Why?'));
      await t.pumpAndSettle();
      await t.tapAndSettle(find.textContaining('· Why?'));
      expect(find.text('Why it changed'), findsOneWidget);
    });

    testWidgets('small talk changes nothing', (t) async {
      final h = await pumpHearth(t);
      await h.push('/chat/c2');
      await h.container.read(relationshipsProvider.notifier).ensure('jun');
      final before = relOf(h, 'jun').values;
      await send(t, 'ok');
      expect(relOf(h, 'jun').values, before);
      expect(find.textContaining('· Why?'), findsNothing);
    });

    testWidgets(
      'deleting a chat keeps its events, marked from a deleted chat',
      (t) async {
        final h = await pumpHearth(t);
        await h.push('/chat/c1');
        await h.container.read(relationshipsProvider.notifier).ensure('vesper');
        await t.tapAndSettle(tooltip('Conversation options'));
        await t.tapAndSettle(find.text('Delete chat…'));
        await t.tapAndSettle(find.text('Delete chat'));
        final e = relOf(h, 'vesper').events.firstWhere((x) => x.id == 'e5');
        expect(e.fromDeletedChat, isTrue);
        await h.go('/characters/vesper/relationship?entry=e5');
        expect(find.text('from a deleted chat'), findsWidgets);
      },
    );
  });

  group('layout', () {
    for (final scale in [1.0, 2.0]) {
      testWidgets('journal fits 360dp wide at ${scale * 100}% text', (t) async {
        final h = await pumpHearth(t, textScale: scale);
        await h.push('/characters/vesper/relationship?entry=e5');
        expect(t.takeException(), isNull);
        expect(find.text('Relationship journal'), findsOneWidget);
      });
    }
  });
}
