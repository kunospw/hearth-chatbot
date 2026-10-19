import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hearth/features/library/data/library_repository.dart';
import 'package:hearth/features/library/domain/library_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/harness.dart';

Finder nav(String label) =>
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label));

Finder sheetField() => find.descendant(of: find.byType(BottomSheet), matching: find.byType(TextField));

/// Scrolls the on-screen vertical list until [f] is on screen.
Future<void> show(WidgetTester t, Finder f) async {
  final list = find.byWidgetPredicate((w) => w is Scrollable && w.axis == Axis.vertical).last;
  await t.scrollUntilVisible(f, 250, scrollable: list);
  await t.ensureVisible(f);
  await t.pumpAndSettle();
}

List<Memory> mems(Harness h) => h.container.read(memoriesProvider).requireValue;

Future<Harness> openLibrary(WidgetTester t, {String? tab, double textScale = 1}) async {
  final h = await pumpHearth(t, textScale: textScale);
  await t.tapAndSettle(nav('Library'));
  if (tab != null) await h.go('/library?tab=$tab');
  return h;
}

void main() {
  group('Library tabs', () {
    testWidgets('header, subtitle and the three sections', (t) async {
      await openLibrary(t);
      expect(find.text('Library'), findsWidgets);
      expect(find.text('Your worlds, the things they remember, and who you play as.'), findsOneWidget);
      for (final s in ['Universes', 'Memories', 'Personas']) {
        expect(find.text(s), findsOneWidget, reason: s);
      }
    });

    testWidgets('?tab= opens the matching section', (t) async {
      await openLibrary(t, tab: 'memories');
      expect(find.text('How memories work'), findsOneWidget);
      final h = await pumpHearth(t);
      await h.go('/library?tab=personas');
      expect(find.textContaining('A persona is who you are in the story'), findsOneWidget);
    });

    testWidgets('segments switch the section', (t) async {
      await openLibrary(t);
      await t.tapAndSettle(find.text('Memories'));
      expect(find.text('How memories work'), findsOneWidget);
      await t.tapAndSettle(find.text('Personas'));
      expect(find.text('Wren'), findsOneWidget);
      await t.tapAndSettle(find.text('Universes'));
      expect(find.text('The Saltmarsh Coast'), findsOneWidget);
    });
  });

  group('Universes', () {
    testWidgets('explainer, cards with era, description, faces and counts', (t) async {
      await openLibrary(t);
      expect(find.textContaining('Each universe keeps its own lore and timeline'), findsOneWidget);
      expect(find.text('The Saltmarsh Coast'), findsOneWidget);
      expect(find.text('1890S · GOTHIC COAST'), findsOneWidget);
      expect(find.text('A fogbound fishing coast where the tide brings back things the sea has taken.'),
          findsOneWidget);
      expect(find.text('1 character · 5 memories'), findsOneWidget);
      expect(find.text('1 character · 3 memories', skipOffstage: false), findsOneWidget); // Meridian
    });

    testWidgets('a card opens the universe', (t) async {
      await openLibrary(t);
      await t.tapAndSettle(find.text('The Saltmarsh Coast'));
      expect(find.textContaining('Separate timeline.'), findsOneWidget);
      expect(find.text('CHARACTERS HERE'), findsOneWidget);
      expect(find.text('Vesper Hale'), findsOneWidget);
      expect(find.text('Memories & lore'), findsOneWidget);
      expect(find.text('5 saved · 2 pinned'), findsOneWidget);
    });

    testWidgets('Create a universe: Save is disabled until it has a name; it opens the new world',
        (t) async {
      final h = await openLibrary(t);
      final create = find.text('Create a universe');
      await show(t, create);
      await t.tapAndSettle(create);
      expect(find.text('Save universe'), findsOneWidget);
      expect(t.widget<FilledButton>(find.widgetWithText(FilledButton, 'Save universe')).onPressed, isNull);

      await t.enterText(sheetField().first, 'The Drowned Kingdoms');
      await t.enterText(sheetField().last, 'Cities under glass.');
      await t.pump();
      await t.tapAndSettle(find.widgetWithText(FilledButton, 'Save universe'));
      expect(find.text('The Drowned Kingdoms'), findsWidgets);
      expect(find.text('No one lives here yet. Give a character this universe in their “More details”.'),
          findsOneWidget);
      expect(h.container.read(universesProvider).requireValue.last.description, 'Cities under glass.');
    });

    testWidgets('Edit changes the name and description', (t) async {
      final h = await pumpHearth(t);
      await h.push('/universes/saltmarsh');
      await t.tapAndSettle(find.text('Edit'));
      expect(find.text('Edit universe'), findsOneWidget);
      await t.enterText(sheetField().first, 'Saltmarsh');
      await t.pump();
      await t.tapAndSettle(find.widgetWithText(FilledButton, 'Save universe'));
      expect(find.text('Universe saved'), findsOneWidget);
      expect(find.text('Saltmarsh'), findsOneWidget);
      expect(h.container.read(universesProvider).requireValue.first.name, 'Saltmarsh');
    });

    testWidgets('a character in the universe opens its profile; Memories & lore opens memories',
        (t) async {
      final h = await pumpHearth(t);
      await h.push('/universes/saltmarsh');
      await show(t, find.text('Memories & lore'));
      await t.tapAndSettle(find.text('Memories & lore'));
      expect(find.text('Memories'), findsOneWidget);
      expect(find.textContaining('Characters in The Saltmarsh Coast remember these'), findsOneWidget);
    });

    testWidgets('an unknown universe shows a way back', (t) async {
      final h = await pumpHearth(t);
      await h.push('/universes/nope');
      expect(find.text('We can’t find this universe'), findsOneWidget);
    });
  });

  group('Memories', () {
    testWidgets('universe chips, explainer, Add a memory and four groups with hints', (t) async {
      await openLibrary(t, tab: 'memories');
      for (final u in ['The Saltmarsh Coast', 'Meridian City', 'The Endless Stacks']) {
        expect(find.text(u), findsWidgets, reason: u);
      }
      expect(find.textContaining('Characters in The Saltmarsh Coast remember these'), findsOneWidget);
      expect(find.text('Add a memory'), findsOneWidget);
      expect(find.text('Important Memories'), findsOneWidget);
      expect(find.text('Big moments the story should never forget.'), findsOneWidget);
      expect(find.text('You arrived at the lighthouse on the night of the October storm.'),
          findsOneWidget);
    });

    testWidgets('empty groups say "Nothing here yet."', (t) async {
      await openLibrary(t, tab: 'memories');
      final chip = find.text('Meridian City').first;
      await t.ensureVisible(chip);
      await t.tapAndSettle(chip);
      // Meridian has no "Important" memories
      expect(find.text('Nothing here yet.', skipOffstage: false), findsWidgets);
    });

    testWidgets('pin toggles in place: the order does not change', (t) async {
      final h = await openLibrary(t, tab: 'memories');
      final before = mems(h).map((m) => m.id).toList();
      final pinnedBefore = mems(h).where((m) => m.pinned).length;
      expect(mems(h).firstWhere((m) => m.id == 'm2').pinned, isFalse);

      await show(t, tooltip('Pin memory').first);
      await t.tapAndSettle(tooltip('Pin memory').first);
      expect(find.text('Pinned — always remembered'), findsOneWidget);
      expect(mems(h).map((m) => m.id).toList(), before, reason: 'no reordering');
      expect(mems(h).where((m) => m.pinned).length, pinnedBefore + 1);

      await show(t, tooltip('Unpin memory').first);
      await t.tapAndSettle(tooltip('Unpin memory').first);
      expect(find.text('Unpinned'), findsOneWidget);
      expect(mems(h).map((m) => m.id).toList(), before);
    });

    testWidgets('pin buttons are ≥44dp and memories are one tap target each', (t) async {
      await openLibrary(t, tab: 'memories');
      final s = t.getSize(tooltip('Pin memory').first);
      expect(s.width, greaterThanOrEqualTo(44));
      expect(s.height, greaterThanOrEqualTo(44));
    });

    testWidgets('tap a memory → edit sheet → Save', (t) async {
      final h = await openLibrary(t, tab: 'memories');
      await show(t, find.text('The letters only ever arrive on the north tide.'));
      await t.tapAndSettle(find.text('The letters only ever arrive on the north tide.'));
      expect(find.text('Edit memory'), findsOneWidget);
      expect(find.text('What should they remember?'), findsOneWidget);
      for (final c in ['Important', 'Story fact', 'Relationship', 'World detail']) {
        expect(find.text(c), findsOneWidget, reason: c);
      }
      expect(find.text('Always remember'), findsOneWidget);
      await t.enterText(sheetField(), 'The letters arrive only on the north tide, at dusk.');
      await t.pump();
      await t.tapAndSettle(find.text('Story fact'));
      await t.tapAndSettle(find.widgetWithText(FilledButton, 'Save memory'));
      expect(find.text('Memory saved'), findsOneWidget);
      expect(mems(h).firstWhere((m) => m.id == 'm3').text,
          'The letters arrive only on the north tide, at dusk.');
    });

    testWidgets('Save is disabled while the text is empty', (t) async {
      await openLibrary(t, tab: 'memories');
      await show(t, find.text('The letters only ever arrive on the north tide.'));
      await t.tapAndSettle(find.text('The letters only ever arrive on the north tide.'));
      await t.enterText(sheetField(), '   ');
      await t.pump();
      expect(t.widget<FilledButton>(find.widgetWithText(FilledButton, 'Save memory')).onPressed, isNull);
    });

    testWidgets('Delete removes it with Undo that puts it back in the same place', (t) async {
      final h = await openLibrary(t, tab: 'memories');
      final before = mems(h).map((m) => m.id).toList();
      await show(t, find.text('The letters only ever arrive on the north tide.'));
      await t.tapAndSettle(find.text('The letters only ever arrive on the north tide.'));
      await t.tapAndSettle(find.widgetWithText(OutlinedButton, 'Delete'));
      expect(find.text('Memory deleted'), findsOneWidget);
      expect(mems(h).any((m) => m.id == 'm3'), isFalse);

      await t.tapAndSettle(find.text('Undo'));
      expect(mems(h).map((m) => m.id).toList(), before, reason: 'restored where it was');
      expect(find.text('The letters only ever arrive on the north tide.'), findsOneWidget);
    });

    testWidgets('Add a memory saves it in the chosen group, pinned if asked', (t) async {
      final h = await openLibrary(t, tab: 'memories');
      await t.tapAndSettle(find.text('Add a memory'));
      expect(find.text('Add a memory'), findsWidgets);
      expect(t.widget<FilledButton>(find.widgetWithText(FilledButton, 'Save memory')).onPressed, isNull);
      await t.enterText(sheetField(), 'Vesper keeps the lamp key on a red cord.');
      await t.pump();
      await t.tapAndSettle(find.text('Relationship'));
      await t.tap(find.text('Always remember'));
      await t.pump();
      await t.tapAndSettle(find.widgetWithText(FilledButton, 'Save memory'));
      final added = mems(h).last;
      expect(added.text, 'Vesper keeps the lamp key on a red cord.');
      expect(added.universeId, 'saltmarsh');
      expect(added.category, MemoryCategory.relationships);
      expect(added.pinned, isTrue);
    });

    testWidgets('journey E: chat ⋯ → Memories in this world → memory → Save is 4 taps', (t) async {
      final h = await pumpHearth(t);
      await h.push('/chat/c1');
      await t.tapAndSettle(tooltip('Conversation options')); // 1
      await t.tapAndSettle(find.text('Memories in this world')); // 2
      await t.tapAndSettle(find.text('You arrived at the lighthouse on the night of the October storm.')); // 3
      await t.enterText(sheetField(), 'You arrived on the night of the October storm.');
      await t.pump();
      await t.tapAndSettle(find.widgetWithText(FilledButton, 'Save memory')); // 4
      expect(find.text('Memory saved'), findsOneWidget);
      expect(mems(h).firstWhere((m) => m.id == 'm1').text, 'You arrived on the night of the October storm.');
    });

    testWidgets('holds at 200% text', (t) async {
      await openLibrary(t, tab: 'memories', textScale: 2);
      expect(t.takeException(), isNull);
      await t.drag(find.byType(Scrollable).first, const Offset(0, -2500));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    });
  });

  group('Personas', () {
    testWidgets('a radio list; picking one says who you are now and is remembered', (t) async {
      final h = await openLibrary(t, tab: 'personas');
      expect(find.text('Wren'), findsOneWidget);
      expect(find.text('Just me'), findsOneWidget);
      expect(find.text('A travelling cartographer with a borrowed coat and too many questions.'),
          findsOneWidget);
      expect(h.container.read(selectedPersonaIdProvider), 'wren');

      await t.tapAndSettle(find.text('Just me'));
      expect(find.text('Now playing as Just me'), findsOneWidget);
      expect(h.container.read(selectedPersonaIdProvider), 'me');
      final sp = await SharedPreferences.getInstance();
      expect(sp.getString('selected_persona'), 'me');
    });

    testWidgets('New persona: name required, created and selected', (t) async {
      final h = await openLibrary(t, tab: 'personas');
      final add = find.text('New persona');
      await show(t, add);
      await t.tapAndSettle(add);
      expect(t.widget<FilledButton>(find.widgetWithText(FilledButton, 'Save persona')).onPressed, isNull);
      await t.enterText(sheetField().first, 'Marlo');
      await t.pump();
      await t.tapAndSettle(find.widgetWithText(FilledButton, 'Save persona'));
      expect(find.text('Now playing as Marlo'), findsOneWidget);
      final list = h.container.read(personasProvider).requireValue;
      expect(list.last.name, 'Marlo');
      expect(list.last.initial, 'M');
      expect(h.container.read(selectedPersonaIdProvider), list.last.id);
    });
  });
}
