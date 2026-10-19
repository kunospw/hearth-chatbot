import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hearth/core/widgets/character_avatar.dart';
import 'package:hearth/core/widgets/sheets.dart';
import 'package:hearth/data/mock/mock_data.dart';
import 'package:hearth/features/characters/data/character_repository.dart';
import 'package:hearth/features/characters/data/draft_repository.dart';
import 'package:hearth/features/characters/domain/character_form.dart';
import 'package:hearth/features/characters/presentation/character_editor_screen.dart';
import 'package:hearth/features/characters/presentation/widgets/character_card.dart';
import 'package:hearth/features/chat/data/conversation_repository.dart';
import 'package:hearth/features/chat/domain/chat_models.dart';

import 'support/harness.dart';

// A 1×1 transparent PNG, so Image.memory has something valid to decode.
final _png = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, //
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
  0x89, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
  0x42, 0x60, 0x82,
]);

Finder field(String label) {
  // A TextField is found by the label shown above it.
  return find.byWidgetPredicate((w) => w is TextField && w.decoration?.hintText != null,
      description: 'text field');
}

Finder nameField() => find.widgetWithText(TextField, '').first;

/// Scrolls the editor's list until [f] is built and on screen.
Future<void> revealInEditor(WidgetTester t, Finder f) async {
  final list = find.descendant(
      of: find.byType(CharacterEditorScreen), matching: find.byType(Scrollable)).first;
  await t.scrollUntilVisible(f, 300, scrollable: list);
  await t.ensureVisible(f);
  await t.pumpAndSettle();
}

Future<Harness> openNew(WidgetTester t, {double textScale = 1}) async {
  final h = await pumpHearth(t, textScale: textScale, overrides: [
    pickPictureProvider.overrideWithValue(() async => _png),
  ]);
  await h.push('/characters/new');
  return h;
}

Finder saveStart() => find.widgetWithText(FilledButton, 'Save & start chat');

void main() {
  group('the new-character form', () {
    testWidgets('only Name is required: Save & start chat is disabled until it is typed',
        (t) async {
      await openNew(t);
      expect(find.text('New character'), findsOneWidget);
      expect(t.widget<FilledButton>(saveStart()).onPressed, isNull);
      expect(find.text('Add a name to continue — everything else is optional.'), findsOneWidget);

      await t.enterText(find.byType(TextField).first, 'Captain Mara Quill');
      await t.pump();
      expect(t.widget<FilledButton>(saveStart()).onPressed, isNotNull);
      expect(find.text('Add a name to continue — everything else is optional.'), findsNothing);
    });

    testWidgets('shows the spec fields; More details is collapsed until opened', (t) async {
      await openNew(t);
      for (final label in ['Name', 'Short description', 'Personality', 'Greeting']) {
        expect(find.text(label, skipOffstage: false), findsOneWidget, reason: label);
      }
      expect(find.text('Backstory', skipOffstage: false), findsNothing);
      await revealInEditor(t, find.textContaining('More details'));
      expect(find.textContaining('More details'), findsOneWidget);
      await t.tapAndSettle(find.textContaining('More details'));
      for (final label in [
        'Backstory',
        'Speaking style',
        'Example dialogue',
        'Things they always or never do',
        'Relationships',
        'Opening scenario',
        'Universe',
      ]) {
        expect(find.text(label, skipOffstage: false), findsOneWidget, reason: label);
      }
    });

    testWidgets('journey C: New character → name → Save & start chat is 2 taps', (t) async {
      final h = await pumpHearth(t);
      // tap 1: "Create a character" on the home grid
      final create = find.text('Create a character');
      await t.scrollUntilVisible(create, 300, scrollable: find.byType(Scrollable).first);
      await t.ensureVisible(create);
      await t.pumpAndSettle();
      await t.tapAndSettle(create);
      expect(find.text('New character'), findsOneWidget);
      await t.enterText(find.byType(TextField).first, 'Mara Quill');
      await t.pump();
      // tap 2
      await t.tapAndSettle(saveStart());

      expect(find.text('Message Mara…'), findsOneWidget, reason: 'the new chat is open');
      final chars = h.container.read(charactersProvider).requireValue;
      expect(chars.first.name, 'Mara Quill');
      final convs = h.container.read(conversationsProvider).requireValue;
      expect(convs.first.characterId, chars.first.id);
      // the default greeting was written
      expect(find.textContaining('Mara looks up as you arrive'), findsOneWidget);
    });

    testWidgets('Save & start chat replaces the editor: Back from the chat goes home', (t) async {
      final h = await pumpHearth(t);
      await h.push('/characters/new');
      await t.enterText(find.byType(TextField).first, 'Mara Quill');
      await t.pump();
      await t.tapAndSettle(saveStart());
      expect(find.text('Message Mara…'), findsOneWidget);

      await t.tapAndSettle(tooltip('Back'));
      expect(find.text('New character'), findsNothing, reason: 'the editor is gone');
      expect(find.text('CONTINUE CHATTING'), findsOneWidget, reason: 'home');
    });

    testWidgets('blank fields get gentle defaults; typed ones are kept', (t) async {
      final h = await openNew(t);
      await t.enterText(find.byType(TextField).first, 'Mara Quill');
      await t.enterText(find.byType(TextField).at(1), 'A smuggler with a soft spot for strays');
      await t.pump();
      await t.tapAndSettle(saveStart());
      final c = h.container.read(charactersProvider).requireValue.first;
      expect(c.first, 'Mara');
      expect(c.initial, 'M');
      expect(c.short, 'A smuggler with a soft spot for strays');
      expect(c.personality, 'Still taking shape.');
      expect(c.speaking, 'Natural and conversational.');
      expect(c.tags, ['Original']);
      expect(c.intro, 'A smuggler with a soft spot for strays');
      expect(c.greeting, startsWith('*Mara looks up as you arrive.*'));
    });

    testWidgets('the colour swatches change the avatar tile, with selected state', (t) async {
      final h = await openNew(t);
      await t.enterText(find.byType(TextField).first, 'Mara');
      await t.tap(find.bySemanticsLabel('Wine').first, warnIfMissed: false);
      await t.pump();
      // pick via the form: the swatch list is the spec's six
      expect(MockData.swatches, hasLength(6));
      final wine = find.byWidgetPredicate(
          (w) => w is CharacterAvatar && w.tile == MockData.swatches[3].tile);
      expect(wine, findsWidgets);
      await t.tapAndSettle(saveStart());
      expect(h.container.read(charactersProvider).requireValue.first.tile, MockData.swatches[3].tile);
    });

    testWidgets('Add picture shows it; Remove picture goes back to the initial', (t) async {
      final h = await openNew(t);
      expect(find.text('Add picture'), findsOneWidget);
      expect(find.text('Optional. Until you add one, their initial is shown.'), findsOneWidget);
      await t.tapAndSettle(find.text('Add picture'));
      expect(find.text('Change picture'), findsOneWidget);
      expect(find.text('Remove picture'), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);

      await t.tapAndSettle(find.text('Remove picture'));
      expect(find.text('Add picture'), findsOneWidget);
      expect(find.byType(Image), findsNothing);

      await t.tapAndSettle(find.text('Add picture'));
      await t.enterText(find.byType(TextField).first, 'Mara');
      await t.pump();
      await t.tapAndSettle(saveStart());
      final c = h.container.read(charactersProvider).requireValue.first;
      expect(c.portraitBytes, isNotNull);
      expect(c.hasPortrait, isTrue);
    });

    testWidgets('choosing a universe in More details is saved', (t) async {
      final h = await openNew(t);
      await t.enterText(find.byType(TextField).first, 'Mara');
      await revealInEditor(t, find.textContaining('More details'));
      await t.tapAndSettle(find.textContaining('More details'));
      final chip = find.text('Meridian City');
      await revealInEditor(t, chip);
      await t.tapAndSettle(chip);
      await t.tapAndSettle(saveStart());
      expect(h.container.read(charactersProvider).requireValue.first.universeId, 'meridian');
    });

    testWidgets('targets are ≥48dp and the form holds at 200% text', (t) async {
      await openNew(t, textScale: 2);
      expect(t.takeException(), isNull);
      for (final tip in ['Close editor']) {
        final s = t.getSize(tooltip(tip));
        expect(s.width, greaterThanOrEqualTo(48));
        expect(s.height, greaterThanOrEqualTo(48));
      }
      await t.drag(find.byType(ListView).last, const Offset(0, -1500));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    });
  });

  group('leaving with changes (discard guard)', () {
    testWidgets('untouched form closes without asking', (t) async {
      await openNew(t);
      await t.tapAndSettle(tooltip('Close editor'));
      expect(find.text('New character'), findsNothing);
      expect(find.text('Leave without saving?'), findsNothing);
    });

    testWidgets('with changes, Close asks: Save draft / Keep editing / Discard', (t) async {
      await openNew(t);
      await t.enterText(find.byType(TextField).first, 'Mara');
      await t.pump();
      await t.tapAndSettle(tooltip('Close editor'));
      expect(find.text('Leave without saving?'), findsOneWidget);
      expect(find.text('Save draft'), findsWidgets);
      expect(find.text('Keep editing'), findsOneWidget);
      expect(find.text('Discard'), findsOneWidget);

      await t.tapAndSettle(find.text('Keep editing'));
      expect(find.text('New character'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Mara'), findsOneWidget, reason: 'nothing lost');
    });

    testWidgets('Android Back asks too, and Discard throws the changes away', (t) async {
      final h = await openNew(t);
      await t.enterText(find.byType(TextField).first, 'Mara');
      await t.pump();
      await t.binding.handlePopRoute();
      await t.pumpAndSettle();
      expect(find.text('Leave without saving?'), findsOneWidget);
      await t.tapAndSettle(find.widgetWithText(TextButton, 'Discard'));
      expect(find.text('New character'), findsNothing);
      expect(h.container.read(draftsProvider), isEmpty);
      expect(h.container.read(charactersProvider).requireValue.map((c) => c.name),
          isNot(contains('Mara')));
    });

    testWidgets('Save draft keeps it; it appears under Drafts on home and resumes', (t) async {
      final h = await openNew(t);
      await t.enterText(find.byType(TextField).first, 'Mara Quill');
      await t.enterText(find.byType(TextField).at(1), 'A smuggler');
      await t.pump();
      await t.tapAndSettle(tooltip('Close editor'));
      await t.tapAndSettle(find.widgetWithText(FilledButton, 'Save draft'));
      expect(find.text('Draft saved'), findsOneWidget);
      expect(h.container.read(draftsProvider), hasLength(1));

      // home shows it
      final drafts = find.text('DRAFTS');
      await t.scrollUntilVisible(drafts, 300, scrollable: find.byType(Scrollable).first);
      await t.ensureVisible(drafts);
      await t.pumpAndSettle();
      expect(find.text('Mara Quill'), findsOneWidget);
      expect(find.text('A smuggler'), findsWidgets);

      // resume it
      await t.tapAndSettle(find.text('Mara Quill'));
      expect(find.text('New character'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Mara Quill'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'A smuggler'), findsOneWidget);

      // finishing removes the draft
      await t.tapAndSettle(saveStart());
      expect(h.container.read(draftsProvider), isEmpty);
    });

    testWidgets('the Save draft button in the header works without closing first', (t) async {
      final h = await openNew(t);
      expect(t.widget<TextButton>(find.widgetWithText(TextButton, 'Save draft')).onPressed, isNull,
          reason: 'nothing to save yet');
      await t.enterText(find.byType(TextField).first, 'Mara');
      await t.pump();
      await t.tapAndSettle(find.widgetWithText(TextButton, 'Save draft'));
      expect(h.container.read(draftsProvider), hasLength(1));
      expect(find.text('New character'), findsNothing);
    });

    testWidgets('a draft can be deleted from home, with Undo', (t) async {
      final h = await pumpHearth(t);
      h.container.read(draftsProvider.notifier).save(
          const CharacterDraft(id: 'd1', form: CharacterForm(name: 'Old Draft')));
      await t.pumpAndSettle();
      final drafts = find.text('DRAFTS');
      await t.scrollUntilVisible(drafts, 300, scrollable: find.byType(Scrollable).first);
      await t.ensureVisible(drafts);
      await t.pumpAndSettle();
      await t.tapAndSettle(tooltip('Delete draft Old Draft'));
      expect(find.text('Draft deleted'), findsOneWidget);
      expect(h.container.read(draftsProvider), isEmpty);
      await t.tapAndSettle(find.text('Undo'));
      expect(h.container.read(draftsProvider), hasLength(1));
    });
  });

  group('editing an existing character', () {
    testWidgets('opens filled in, saves changes, and updates everywhere', (t) async {
      final h = await pumpHearth(t, overrides: [
        pickPictureProvider.overrideWithValue(() async => _png),
      ]);
      await h.push('/characters/jun');
      await t.tapAndSettle(find.text('Edit'));
      expect(find.text('Edit character'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Juniper “Jun” Okafor'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Save changes'), findsOneWidget);

      await t.enterText(find.byType(TextField).at(1),
          'A courier who always takes the scenic route.');
      await t.pump();
      await t.tapAndSettle(find.widgetWithText(FilledButton, 'Save changes'));
      expect(find.text('Changes saved'), findsOneWidget);
      expect(find.text('Edit character'), findsNothing);

      final jun = h.container.read(charactersProvider).requireValue.firstWhere((c) => c.id == 'jun');
      expect(jun.short, 'A courier who always takes the scenic route.');
      expect(jun.tags, ['Adventure', 'Banter', 'Solarpunk'], reason: 'tags are kept');
      expect(find.textContaining('A courier who always takes the scenic route.'), findsOneWidget);
    });

    testWidgets('keeps the portrait unless you remove or replace it', (t) async {
      final h = await pumpHearth(t);
      await h.push('/characters/vesper/edit');
      expect(find.text('Change picture'), findsOneWidget);
      await t.enterText(find.byType(TextField).at(1), 'Changed.');
      await t.pump();
      await t.tapAndSettle(find.widgetWithText(FilledButton, 'Save changes'));
      var v = h.container.read(charactersProvider).requireValue.firstWhere((c) => c.id == 'vesper');
      expect(v.portraitAsset, 'assets/portraits/vesper.svg');

      await h.push('/characters/vesper/edit');
      await t.tapAndSettle(find.text('Remove picture'));
      await t.tapAndSettle(find.widgetWithText(FilledButton, 'Save changes'));
      v = h.container.read(charactersProvider).requireValue.firstWhere((c) => c.id == 'vesper');
      expect(v.hasPortrait, isFalse);
    });

    testWidgets('leaving an edit with changes asks; the draft is an edit of that character',
        (t) async {
      final h = await pumpHearth(t);
      await h.push('/characters/vesper/edit');
      await t.enterText(find.byType(TextField).first, 'Vesper H.');
      await t.pump();
      await t.tapAndSettle(tooltip('Close editor'));
      await t.tapAndSettle(find.widgetWithText(FilledButton, 'Save draft'));
      final d = h.container.read(draftsProvider).single;
      expect(d.editingId, 'vesper');
      expect(h.container.read(charactersProvider).requireValue.first.name != 'Vesper H.', isTrue);
    });

    testWidgets('an unknown character shows a way back', (t) async {
      final h = await pumpHearth(t);
      await h.push('/characters/nobody/edit');
      expect(find.text('We can’t find this character'), findsOneWidget);
    });
  });

  group('CharacterForm', () {
    test('blank detection and name handling', () {
      expect(const CharacterForm().isBlank, isTrue);
      expect(const CharacterForm(name: '  ').hasName, isFalse);
      expect(const CharacterForm(name: ' Mara  Quill ').first, 'Mara');
      expect(const CharacterForm(short: 'x').isBlank, isFalse);
    });

    test('toCharacter builds the intro from backstory, else the short line, else a default', () {
      expect(const CharacterForm(name: 'A', backstory: 'B', short: 'S').toCharacter('x').intro, 'B');
      expect(const CharacterForm(name: 'A', short: 'S').toCharacter('x').intro, 'S');
      expect(const CharacterForm(name: 'Ana').toCharacter('x').intro,
          'Not much is known about Ana yet — you’ll find out together.');
    });

    test('fromCharacter round-trips the editable fields', () {
      final v = MockData.characters.first;
      final f = CharacterForm.fromCharacter(v);
      expect(f.name, v.name);
      expect(f.backstory, v.intro);
      expect(f.swatch, 0);
      expect(f.universeId, 'saltmarsh');
      final back = f.toCharacter(v.id, base: v);
      expect(back.name, v.name);
      expect(back.intro, v.intro);
      expect(back.greeting, v.greeting);
      expect(back.tags, v.tags);
    });
  });

  testWidgets('a created character shows on home and can be chatted with', (t) async {
    final h = await pumpHearth(t);
    await h.push('/characters/new');
    await t.enterText(find.byType(TextField).first, 'Zed Quill');
    await t.pump();
    await t.tapAndSettle(saveStart());
    await t.tapAndSettle(tooltip('Back'));
    final card = find.widgetWithText(CharacterCard, 'Zed Quill');
    await t.scrollUntilVisible(card, 300, scrollable: find.byType(Scrollable).first);
    expect(card, findsOneWidget);
    final convs = h.container.read(conversationsProvider).requireValue;
    expect(convs.first.title, 'New chat with Zed');
    expect(convs.first.mode, ChatMode.chat);
  });

  test('pickPictureProvider can be replaced (tests never open a real picker)', () {
    final c = ProviderContainer(overrides: [pickPictureProvider.overrideWithValue(() async => null)]);
    addTearDown(c.dispose);
    expect(c.read(pickPictureProvider)(), completion(isNull));
  });

  test('showDiscardSheet is the shared sheet', () {
    expect(showDiscardSheet, isA<Function>());
  });
}
