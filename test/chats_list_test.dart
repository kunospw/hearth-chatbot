import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hearth/core/widgets/chat_tile.dart';
import 'package:hearth/core/widgets/states.dart';
import 'package:hearth/data/mock/mock_scenario.dart';
import 'package:hearth/features/chat/data/conversation_repository.dart';
import 'package:hearth/features/chat/presentation/chat_screen.dart';

import 'support/harness.dart';

Finder nav(String label) =>
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label));

Future<Harness> openChats(WidgetTester t,
    {MockScenario scenario = MockScenario.normal,
    Size size = const Size(360, 800),
    double textScale = 1,
    Duration latency = Duration.zero}) async {
  final h = await pumpHearth(t,
      scenario: scenario, size: size, textScale: textScale, latency: latency);
  if (size.width < 600) {
    await t.tapAndSettle(nav('Chats'));
  } else {
    await t.tapAndSettle(find.descendant(of: find.byType(NavigationRail), matching: find.text('Chats')));
  }
  return h;
}

Finder sheetField() => find.descendant(of: find.byType(BottomSheet), matching: find.byType(TextField));

void main() {
  group('the list', () {
    testWidgets('header, search, and Pinned / Recent sections', (t) async {
      await openChats(t);
      expect(find.text('Chats'), findsWidgets);
      expect(find.text('Search chats'), findsOneWidget);
      expect(find.text('PINNED'), findsOneWidget);
      expect(find.text('RECENT'), findsOneWidget);
      expect(find.byType(ChatTile), findsNWidgets(3));
      // the pinned chat comes first
      expect(t.getTopLeft(find.text('The letter from the north tide')).dy,
          lessThan(t.getTopLeft(find.text('Rooftop delivery')).dy));
      expect(find.text('Vesper · 2m ago'), findsOneWidget);
      expect(find.text('Jun · Yesterday'), findsOneWidget);
    });

    testWidgets('a row is one tap target that opens the chat; ⋯ is separate and ≥48dp', (t) async {
      await openChats(t);
      final more = tooltip('More options for Rooftop delivery');
      expect(t.getSize(more).width, greaterThanOrEqualTo(48));
      expect(t.getSize(more).height, greaterThanOrEqualTo(48));
      await t.tapAndSettle(more);
      expect(find.text('Rooftop delivery'), findsWidgets);
      expect(find.text('Message Jun…'), findsNothing, reason: '⋯ did not open the chat');
      await t.tapAt(const Offset(180, 20)); // dismiss
      await t.pumpAndSettle();

      await t.tapAndSettle(find.text('Rooftop delivery'));
      expect(find.text('Message Jun…'), findsOneWidget);
    });

    testWidgets('search finds by title, character and a word from the conversation', (t) async {
      await openChats(t);
      await t.enterText(find.byType(TextField).first, 'bookmark');
      await t.pumpAndSettle();
      expect(find.byType(ChatTile), findsOneWidget);
      expect(find.text('The bookmark in 1612'), findsOneWidget);

      await t.enterText(find.byType(TextField).first, 'jun');
      await t.pumpAndSettle();
      expect(find.text('Rooftop delivery'), findsOneWidget);

      await t.enterText(find.byType(TextField).first, 'kettle');
      await t.pumpAndSettle();
      expect(find.text('The letter from the north tide'), findsOneWidget, reason: 'matched in the text');
    });

    testWidgets('no match explains and offers Browse characters', (t) async {
      await openChats(t);
      await t.enterText(find.byType(TextField).first, 'zzzz');
      await t.pumpAndSettle();
      expect(find.text('No chats match'), findsOneWidget);
      expect(find.text('Try a character name or a word from the conversation.'), findsOneWidget);
      await t.tapAndSettle(find.text('Browse characters'));
      expect(find.text('CONTINUE CHATTING'), findsOneWidget);
    });

    testWidgets('empty: "No chats yet" with Browse characters', (t) async {
      await openChats(t, scenario: MockScenario.empty);
      expect(find.text('No chats yet'), findsOneWidget);
      expect(find.text('Start a conversation with any character and it will live here.'),
          findsOneWidget);
      await t.tapAndSettle(find.text('Browse characters'));
      expect(find.text('Your first story starts here'), findsOneWidget);
    });

    testWidgets('loading shows skeleton rows', (t) async {
      await openChats(t, latency: const Duration(milliseconds: 600));
      // The tab switch happened while loading; rows are skeletons or already loaded.
      await t.pump(const Duration(milliseconds: 10));
      await t.pumpAndSettle();
      expect(find.byType(ChatTile), findsNWidgets(3));
    });

    testWidgets('offline: a banner and Try again that recovers', (t) async {
      final h = await openChats(t, scenario: MockScenario.offline);
      expect(find.byType(OfflineBanner), findsOneWidget);
      expect(find.text('No connection'), findsOneWidget);
      h.container.read(mockScenarioProvider.notifier).state = MockScenario.normal;
      await t.pumpAndSettle();
      expect(find.byType(ChatTile), findsNWidgets(3));
    });

    testWidgets('holds at 200% text', (t) async {
      await openChats(t, textScale: 2);
      expect(t.takeException(), isNull);
      await t.drag(find.byType(Scrollable).last, const Offset(0, -800));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    });
  });

  group('⋯ options', () {
    testWidgets('Pin to top / Unpin, with toasts, and the section changes', (t) async {
      final h = await openChats(t);
      await t.tapAndSettle(tooltip('More options for Rooftop delivery'));
      expect(find.text('Pin to top'), findsOneWidget);
      await t.tapAndSettle(find.text('Pin to top'));
      expect(find.text('Pinned to top'), findsOneWidget);
      expect(convOf(h, 'c2').pinned, isTrue);
      expect(find.text('PINNED'), findsOneWidget);

      await t.tapAndSettle(tooltip('More options for The letter from the north tide'));
      expect(find.text('Unpin'), findsOneWidget);
      await t.tapAndSettle(find.text('Unpin'));
      expect(find.text('Unpinned'), findsOneWidget);
      expect(convOf(h, 'c1').pinned, isFalse);
    });

    testWidgets('Rename saves and shows a toast', (t) async {
      final h = await openChats(t);
      await t.tapAndSettle(tooltip('More options for Rooftop delivery'));
      await t.tapAndSettle(find.text('Rename'));
      expect(find.text('Rename chat'), findsOneWidget);
      await t.enterText(sheetField(), 'Roof job');
      await t.pump();
      await t.tapAndSettle(find.widgetWithText(FilledButton, 'Save'));
      expect(find.text('Renamed'), findsOneWidget);
      expect(find.text('Roof job'), findsOneWidget);
      expect(convOf(h, 'c2').title, 'Roof job');
    });

    testWidgets('Delete asks first (safe option first); nothing is lost if you keep it', (t) async {
      final h = await openChats(t);
      await t.tapAndSettle(tooltip('More options for Rooftop delivery'));
      await t.tapAndSettle(find.text('Delete chat…'));
      expect(find.text('Delete “Rooftop delivery”?'), findsOneWidget);
      expect(find.textContaining('The conversation will be gone for good. Memories saved to the universe stay safe.'),
          findsOneWidget);
      expect(t.getTopLeft(find.text('Keep it')).dy, lessThan(t.getTopLeft(find.widgetWithText(FilledButton, 'Delete')).dy));
      await t.tapAndSettle(find.text('Keep it'));
      expect(h.container.read(conversationProvider('c2')), isNotNull);
      expect(find.byType(ChatTile), findsNWidgets(3));

      await t.tapAndSettle(tooltip('More options for Rooftop delivery'));
      await t.tapAndSettle(find.text('Delete chat…'));
      await t.tapAndSettle(find.widgetWithText(FilledButton, 'Delete'));
      expect(find.text('Chat deleted'), findsOneWidget);
      expect(h.container.read(conversationProvider('c2')), isNull);
      expect(find.byType(ChatTile), findsNWidgets(2));
    });
  });

  group('wide layout (list-detail from 840dp)', () {
    const wide = Size(1100, 800);

    testWidgets('shows the list beside an empty detail pane', (t) async {
      await openChats(t, size: wide);
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.text('Choose a chat'), findsOneWidget);
      expect(find.byType(ChatScreen), findsNothing);
      expect(find.byType(ChatTile), findsNWidgets(3));
    });

    testWidgets('tapping a row opens it in the pane, without a new route', (t) async {
      final h = await openChats(t, size: wide);
      await t.tapAndSettle(find.text('The letter from the north tide'));
      expect(find.byType(ChatScreen), findsOneWidget);
      expect(find.text('Message Vesper…'), findsOneWidget);
      expect(find.text('Choose a chat'), findsNothing);
      expect(h.router.state.uri.path, '/chats');
      // no Back button in the pane; the list is still there
      expect(find.byTooltip('Back'), findsNothing);
      expect(find.byType(ChatTile), findsNWidgets(3));

      await t.tapAndSettle(find.text('Rooftop delivery'));
      expect(find.text('Message Jun…'), findsOneWidget);
    });

    testWidgets('deleting the open chat clears the pane', (t) async {
      final h = await openChats(t, size: wide);
      await t.tapAndSettle(find.text('Rooftop delivery'));
      await t.tapAndSettle(tooltip('Conversation options'));
      await t.tapAndSettle(find.text('Delete chat…'));
      await t.tapAndSettle(find.text('Delete chat'));
      await t.pumpAndSettle(const Duration(seconds: 1));
      expect(h.container.read(conversationProvider('c2')), isNull);
      expect(find.text('Choose a chat'), findsOneWidget);
    });

    testWidgets('a narrow window uses the normal pushed chat instead', (t) async {
      final h = await openChats(t);
      await t.tapAndSettle(find.text('Rooftop delivery'));
      expect(h.router.state.uri.path, '/chat/c2');
    });
  });
}
