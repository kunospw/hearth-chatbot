import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hearth/core/widgets/controls.dart';
import 'package:hearth/features/characters/data/character_repository.dart';
import 'package:hearth/features/characters/domain/character_form.dart';
import 'package:hearth/features/characters/presentation/character_editor_screen.dart';
import 'package:hearth/features/relationship/data/relationship_providers.dart';
import 'package:hearth/features/relationship/domain/relationship_bands.dart';
import 'package:hearth/features/relationship/domain/relationship_models.dart';

import 'support/harness.dart';

// Starting points: roleplay a relationship that already exists (a couple, old
// friends, family, rivals) instead of always beginning as strangers.

Relationship relOf(Harness h, String character) =>
    h.container.read(relationshipProvider(character)).valueOrNull!;

Finder chip(String label) =>
    find.ancestor(of: find.text(label), matching: find.byType(HearthChip));

bool selected(WidgetTester t, String label) =>
    t.widget<HearthChip>(chip(label)).selected;

/// Scrolls the editor's list until [f] is on screen.
Future<void> reveal(WidgetTester t, Finder f) async {
  final list = find
      .descendant(
        of: find.byType(CharacterEditorScreen),
        matching: find.byType(Scrollable),
      )
      .first;
  await t.scrollUntilVisible(f, 300, scrollable: list);
  await t.ensureVisible(f);
  await t.pumpAndSettle();
}

TextField greetingField(WidgetTester t) => t.widget<TextField>(
  find.descendant(
    of: find
        .ancestor(of: find.text('Greeting'), matching: find.byType(Column))
        .first,
    matching: find.byType(TextField),
  ),
);

void main() {
  group('the editor', () {
    testWidgets(
      'a new character can start as a couple: the greeting, the chat and the journal follow',
      (t) async {
        final h = await pumpHearth(t);
        await h.push('/characters/new');
        await t.enterText(find.byType(TextField).first, 'Mara Quill');
        await t.pump();
        await reveal(t, chip('Together'));
        expect(find.text('You and Mara'), findsOneWidget);
        expect(
          selected(t, 'Just met'),
          isTrue,
          reason: 'Just met unless you choose',
        );
        expect(find.text(StartingPoint.strangers.hint), findsOneWidget);

        await t.tapAndSettle(chip('Together'));
        expect(selected(t, 'Together'), isTrue);
        expect(selected(t, 'Just met'), isFalse);
        expect(find.text(StartingPoint.together.hint), findsOneWidget);
        await t.tapAndSettle(
          find.widgetWithText(FilledButton, 'Save & start chat'),
        );

        expect(find.text('Message Mara…'), findsOneWidget);
        final c = h.container.read(charactersProvider).requireValue.first;
        expect(c.startingPoint, StartingPoint.together);
        expect(c.greeting, defaultGreeting('Mara', StartingPoint.together));
        expect(find.textContaining('I missed you today'), findsOneWidget);

        await h.push('/characters/${c.id}/relationship');
        final r = relOf(h, c.id);
        expect(r.startingPoint, StartingPoint.together);
        expect(
          (r.stageName, r.type),
          ('Happy Together', RelationType.romantic),
        );
        expect(r.events, isEmpty, reason: 'it simply begins there');
        expect(find.text('Happy Together'), findsWidgets);
        expect(promptBlock(r), contains('history: already a couple'));
      },
    );

    testWidgets(
      'changing it for an existing character warns, then starts the story over and keeps the history',
      (t) async {
        final h = await pumpHearth(t);
        await h.push('/characters/jun/relationship');
        final before = relOf(h, 'jun');
        expect(before.stageName, 'Allies');

        await h.push('/characters/jun/edit');
        await reveal(t, chip('Together'));
        expect(find.textContaining('When you save'), findsNothing);
        await t.tapAndSettle(chip('Together'));
        // (the editor names them by the first word of the name)
        expect(
          find.text(
            'When you save, your story with Juniper starts again from here. '
            'Earlier moments stay in the relationship journal.',
          ),
          findsOneWidget,
        );
        await t.tapAndSettle(find.widgetWithText(FilledButton, 'Save changes'));

        expect(
          find.text('Changes saved — starting point: Together'),
          findsOneWidget,
        );
        expect(
          h.container.read(characterProvider('jun')).valueOrNull!.startingPoint,
          StartingPoint.together,
        );
        final r = relOf(h, 'jun');
        expect(r.startingPoint, StartingPoint.together);
        expect(
          (r.stageName, r.type),
          ('Happy Together', RelationType.romantic),
        );
        expect(r.events.first.title, 'Starting point: Together');
        expect(
          r.events.skip(1).map((e) => e.id),
          before.events.map((e) => e.id),
          reason: 'earlier moments stay in the timeline',
        );
      },
    );

    testWidgets(
      'a greeting we wrote follows the starting point; one you wrote stays',
      (t) async {
        final h = await pumpHearth(t);
        await h.push('/characters/new');
        await t.enterText(find.byType(TextField).first, 'Mara Quill');
        await t.pump();
        await t.tapAndSettle(
          find.widgetWithText(FilledButton, 'Save & start chat'),
        );
        final id = h.container.read(charactersProvider).requireValue.first.id;

        await h.push('/characters/$id/edit');
        await reveal(t, find.text('Greeting'));
        expect(
          greetingField(t).controller!.text,
          defaultGreeting('Mara', StartingPoint.strangers),
        );
        await reveal(t, chip('Rivals'));
        await t.tapAndSettle(chip('Rivals'));
        expect(
          greetingField(t).controller!.text,
          defaultGreeting('Mara', StartingPoint.rivals),
        );

        await t.enterText(
          find.byWidget(greetingField(t)),
          '*Mara salutes.* "Again?"',
        );
        await t.pump();
        await t.tapAndSettle(chip('Friends'));
        expect(greetingField(t).controller!.text, '*Mara salutes.* "Again?"');
      },
    );
  });

  group('the journal', () {
    testWidgets(
      'Starting point says where you began; Change starts over from another one',
      (t) async {
        final h = await pumpHearth(t);
        await h.push('/characters/vesper/relationship');
        expect(find.text('STARTING POINT'), findsOneWidget);
        expect(find.text('Just met'), findsOneWidget);
        expect(find.text(StartingPoint.strangers.hint), findsOneWidget);

        await t.ensureVisible(find.text('Change'));
        await t.pumpAndSettle();
        await t.tapAndSettle(find.text('Change'));
        expect(find.text('Where does your story start?'), findsOneWidget);
        expect(
          find.byType(RadioRow),
          findsNWidgets(StartingPoint.values.length),
        );
        await t.tapAndSettle(find.widgetWithText(RadioRow, 'Together'));
        await t.ensureVisible(find.text('Start from here'));
        await t.pumpAndSettle();
        await t.tapAndSettle(find.text('Start from here'));

        expect(
          find.text(
            'Starting point: Together — the next reply will reflect it',
          ),
          findsOneWidget,
        );
        final r = relOf(h, 'vesper');
        expect(r.startingPoint, StartingPoint.together);
        expect(r.stageName, 'Happy Together');
        expect(find.text('Together'), findsOneWidget);
        expect(find.text(StartingPoint.together.hint), findsOneWidget);

        final entry = find.text('Starting point: Together');
        await t.scrollUntilVisible(
          entry,
          300,
          scrollable: find.byType(Scrollable).first,
        );
        expect(entry, findsOneWidget);
      },
    );

    testWidgets('dismissing the sheet changes nothing', (t) async {
      final h = await pumpHearth(t);
      await h.push('/characters/vesper/relationship');
      final before = relOf(h, 'vesper');
      await t.ensureVisible(find.text('Change'));
      await t.pumpAndSettle();
      await t.tapAndSettle(find.text('Change'));
      await t.tapAndSettle(find.widgetWithText(RadioRow, 'Rivals'));
      // Android Back closes the sheet without choosing
      await t.binding.handlePopRoute();
      await t.pumpAndSettle();
      expect(find.text('Where does your story start?'), findsNothing);
      final after = relOf(h, 'vesper');
      expect(
        (after.startingPoint, after.version),
        (StartingPoint.strangers, before.version),
      );
    });

    testWidgets('the section and the sheet hold at 200% text', (t) async {
      final h = await pumpHearth(t, textScale: 2);
      await h.push('/characters/vesper/relationship');
      final change = find.text('Change');
      await t.scrollUntilVisible(
        change,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await t.tapAndSettle(change);
      expect(find.text('Where does your story start?'), findsOneWidget);
      final start = find.text('Start from here');
      await t.ensureVisible(start);
      await t.pumpAndSettle();
      expect(
        t.getSize(find.widgetWithText(FilledButton, 'Start from here')).height,
        greaterThanOrEqualTo(48),
      );
      for (final row in t.widgetList<RadioRow>(find.byType(RadioRow))) {
        expect(
          t.getSize(find.byWidget(row)).height,
          greaterThanOrEqualTo(48),
          reason: row.title,
        );
      }
      expect(t.takeException(), isNull);
    });
  });
}
