import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hearth/core/widgets/chat_tile.dart';
import 'package:hearth/features/characters/data/character_repository.dart';
import 'package:hearth/features/chat/data/conversation_repository.dart';

import 'support/harness.dart';

Future<void> reveal(WidgetTester t, Finder f) async {
  await t.scrollUntilVisible(f, 300, scrollable: find.byType(Scrollable).first);
  await t.pumpAndSettle();
}

void main() {
  group('chats: archive', () {
    testWidgets('a chat can be archived from the Chats list, found under Archived, and restored', (t) async {
      final h = await pumpHearth(t);
      await h.go('/chats');
      expect(find.byType(ChatTile), findsNWidgets(3));
      await t.tapAndSettle(tooltip('More options for Rooftop delivery'));
      await t.tapAndSettle(find.text('Archive'));
      expect(find.text('Chat archived'), findsOneWidget);
      expect(h.container.read(conversationProvider('c2'))!.archived, isTrue);
      expect(find.byType(ChatTile), findsNWidgets(2));

      await t.tapAndSettle(find.text('Archived (1)'));
      expect(find.byType(ChatTile), findsOneWidget);
      expect(find.text('Rooftop delivery'), findsOneWidget);
      await t.tapAndSettle(tooltip('More options for Rooftop delivery'));
      await t.tapAndSettle(find.text('Unarchive'));
      expect(h.container.read(conversationProvider('c2'))!.archived, isFalse);
      expect(find.text('Nothing archived'), findsOneWidget);
    });

    testWidgets('Undo on the toast brings it straight back', (t) async {
      final h = await pumpHearth(t);
      await h.go('/chats');
      await t.tapAndSettle(tooltip('More options for Rooftop delivery'));
      await t.tapAndSettle(find.text('Archive'));
      await t.tapAndSettle(find.text('Undo'));
      expect(h.container.read(conversationProvider('c2'))!.archived, isFalse);
    });

    testWidgets('archived chats leave Continue chatting on the home screen', (t) async {
      final h = await pumpHearth(t);
      expect(find.text('The letter from the north tide'), findsOneWidget);
      h.container.read(conversationsProvider.notifier).setArchived('c1', true);
      await t.pumpAndSettle();
      expect(find.text('The letter from the north tide'), findsNothing);
    });

    testWidgets('the Continue card has a ⋯ with the same options', (t) async {
      await pumpHearth(t);
      await t.tapAndSettle(tooltip('More options for this chat').first);
      expect(find.text('Archive'), findsOneWidget);
      expect(find.text('Rename'), findsOneWidget);
      expect(find.text('Delete chat…'), findsOneWidget);
    });
  });

  group('characters: archive and delete', () {
    testWidgets('a character card has a ⋯ with Edit, Archive and Delete', (t) async {
      await pumpHearth(t);
      await reveal(t, tooltip('More options for Vesper'));
      await t.tapAndSettle(tooltip('More options for Vesper'));
      expect(find.textContaining('Open profile'), findsOneWidget);
      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Archive'), findsOneWidget);
      expect(find.text('Delete character…'), findsOneWidget);
    });

    testWidgets('archiving hides the character and their chats, and they can be brought back', (t) async {
      final h = await pumpHearth(t);
      await reveal(t, tooltip('More options for Vesper'));
      await t.tapAndSettle(tooltip('More options for Vesper'));
      await t.tapAndSettle(find.text('Archive'));
      expect(find.text('Vesper archived'), findsOneWidget);
      expect(h.container.read(charactersProvider).value!.firstWhere((c) => c.id == 'vesper').archived, isTrue);
      expect(find.text('The letter from the north tide'), findsNothing, reason: 'their chat leaves Continue chatting too');

      await t.pump(const Duration(seconds: 7)); // let the toast go; it floats over the bottom of the list
      await t.pumpAndSettle();
      await reveal(t, find.text('Archived (1)'));
      await t.tapAndSettle(find.text('Archived (1)'));
      await reveal(t, tooltip('More options for Vesper'));
      await t.tapAndSettle(tooltip('More options for Vesper'));
      await t.tapAndSettle(find.text('Unarchive'));
      expect(h.container.read(charactersProvider).value!.firstWhere((c) => c.id == 'vesper').archived, isFalse);
      await t.drag(find.byType(Scrollable).first, const Offset(0, 3000));
      await t.pumpAndSettle();
      expect(find.text('The letter from the north tide'), findsOneWidget);
    });

    testWidgets('deleting asks first, says how many chats go too, then removes them all', (t) async {
      final h = await pumpHearth(t);
      await reveal(t, tooltip('More options for Vesper'));
      await t.tapAndSettle(tooltip('More options for Vesper'));
      await t.tapAndSettle(find.text('Delete character…'));
      expect(find.text('Delete Vesper Hale?'), findsOneWidget);
      expect(find.textContaining('1 chat will be gone for good'), findsOneWidget);
      await t.tapAndSettle(find.text('Keep Vesper'));
      expect(h.container.read(charactersProvider).value!.any((c) => c.id == 'vesper'), isTrue);

      await t.tapAndSettle(tooltip('More options for Vesper'));
      await t.tapAndSettle(find.text('Delete character…'));
      await t.tapAndSettle(find.widgetWithText(FilledButton, 'Delete'));
      expect(find.text('Vesper deleted'), findsOneWidget);
      expect(h.container.read(charactersProvider).value!.any((c) => c.id == 'vesper'), isFalse);
      expect(h.container.read(conversationProvider('c1')), isNull);
    });
  });

  group('old chats', () {
    testWidgets('a character page lists every chat with them, newest first', (t) async {
      final h = await pumpHearth(t);
      h.container.read(conversationsProvider.notifier).startNew(h.container.read(charactersProvider).value!.first);
      await h.push('/characters/vesper');
      await reveal(t, find.text('CHATS WITH VESPER (2)'));
      expect(find.text('The letter from the north tide'), findsOneWidget);
      expect(find.text('New chat with Vesper'), findsOneWidget);
      await t.tapAndSettle(find.text('The letter from the north tide'));
      expect(find.text('Vesper Hale'), findsOneWidget);
    });

    testWidgets('the chat ⋯ menu has “All chats with …” which opens the character page', (t) async {
      final h = await pumpHearth(t);
      await h.push('/chat/c1');
      await t.tapAndSettle(tooltip('Conversation options'));
      await t.tapAndSettle(find.text('All chats with Vesper'));
      expect(find.text('Start new chat'), findsOneWidget);
    });

    testWidgets('the character page has its own ⋯ menu too', (t) async {
      final h = await pumpHearth(t);
      await h.push('/characters/vesper');
      await t.tapAndSettle(tooltip('More options'));
      expect(find.text('Archive'), findsOneWidget);
      expect(find.text('Delete character…'), findsOneWidget);
    });
  });
}
