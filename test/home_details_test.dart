import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hearth/core/widgets/chat_tile.dart';
import 'package:hearth/core/widgets/states.dart';
import 'package:hearth/data/mock/mock_scenario.dart';
import 'package:hearth/features/characters/presentation/character_details_screen.dart';
import 'package:hearth/features/characters/presentation/widgets/character_card.dart';
import 'package:hearth/features/chat/data/conversation_repository.dart';
import 'package:hearth/features/chat/domain/chat_models.dart';

import 'support/harness.dart';

/// The vertical scrollable of the details page (not the home list underneath).
Finder detailsScroll() => find
    .descendant(of: find.byType(CharacterDetailsScreen), matching: find.byType(Scrollable))
    .first;

/// Scrolls the details page until [f] is genuinely on screen (scrollUntilVisible
/// alone stops as soon as the widget is built, which includes the cache area).
Future<void> reveal(WidgetTester t, Finder f) async {
  await t.scrollUntilVisible(f, 200, scrollable: detailsScroll());
  await t.ensureVisible(f);
  await t.pumpAndSettle();
}

void main() {
  group('Character Library (home)', () {
    testWidgets('greets, shows Continue chatting with one large card and two rows', (t) async {
      await pumpHearth(t);
      expect(
        find.textContaining(RegExp('Good (morning|afternoon|evening)')),
        findsOneWidget,
      );
      expect(find.text('CONTINUE CHATTING'), findsOneWidget);
      expect(find.byType(ContinueCard), findsOneWidget);
      expect(find.byType(ChatTile), findsNWidgets(2));
      expect(find.text('The letter from the north tide'), findsOneWidget);
      expect(find.text('Rooftop delivery'), findsOneWidget);
      expect(find.text('The bookmark in 1612'), findsOneWidget);
    });

    testWidgets('journey B: Resume is 1 tap and reopens the newest chat', (t) async {
      await pumpHearth(t);
      await t.tapAndSettle(find.byType(ContinueCard));
      expect(find.text('Vesper Hale'), findsOneWidget); // chat header
      expect(find.text('Message Vesper…'), findsOneWidget);
      // newest message is visible (reopens at the end)
      expect(find.textContaining('They stay sealed until we open them together'), findsOneWidget);
    });

    testWidgets('Resume reopens a chat in the mode it was left in', (t) async {
      final h = await pumpHearth(t);
      h.container.read(conversationsProvider.notifier).setMode('c1', ChatMode.story);
      await t.pumpAndSettle();
      await t.tapAndSettle(find.byType(ContinueCard));
      expect(find.text('VESPER · STORY'), findsOneWidget);
      expect(find.text('What happens next? (optional)'), findsOneWidget);
    });

    testWidgets('recent characters open the profile', (t) async {
      final h = await pumpHearth(t);
      await t.scrollUntilVisible(find.text('YOUR RECENT CHARACTERS'), 300,
          scrollable: find.byType(Scrollable).first);
      await t.pumpAndSettle();
      expect(find.text('YOUR RECENT CHARACTERS'), findsOneWidget);
      await h.push('/characters/morrow');
      expect(find.text('Start new chat'), findsOneWidget);
    });

    testWidgets('journey A: card → Start new chat is 2 taps and opens a fresh chat', (t) async {
      final h = await pumpHearth(t);
      // tap 1: Iselde's card
      final card = find.widgetWithText(CharacterCard, 'Iselde Varr');
      await t.scrollUntilVisible(card, 300, scrollable: find.byType(Scrollable).first);
      await t.pumpAndSettle();
      await t.tapAndSettle(card);
      expect(find.text('Start new chat'), findsOneWidget);
      // tap 2: Start new chat
      await t.tapAndSettle(find.text('Start new chat'));
      expect(find.text('Iselde Varr'), findsOneWidget);
      expect(find.textContaining('Stop right there, reader'), findsOneWidget);
      final list = h.container.read(conversationsProvider).requireValue;
      expect(list.first.title, 'New chat with Iselde');
      expect(list.first.messages, hasLength(1));
    });

    testWidgets('search filters by name, description and tag, with a match count', (t) async {
      await pumpHearth(t);
      await t.enterText(find.byType(TextField), 'gothic');
      await t.pumpAndSettle();
      expect(find.text('1 MATCH'), findsOneWidget);
      expect(find.byType(CharacterCard), findsOneWidget);
      expect(find.text('Vesper Hale'), findsOneWidget);
      expect(find.text('CONTINUE CHATTING'), findsNothing);

      await t.enterText(find.byType(TextField), 'the');
      await t.pumpAndSettle();
      expect(find.text('3 MATCHES'), findsOneWidget); // Vesper, Jun, Morrow
      await t.tapAndSettle(tooltip('Clear search'));
      expect(find.text('CONTINUE CHATTING'), findsOneWidget);
    });

    testWidgets('no match offers to create the searched name', (t) async {
      await pumpHearth(t);
      await t.enterText(find.byType(TextField), 'Zed Quill');
      await t.pumpAndSettle();
      expect(find.text('NO MATCHES'), findsOneWidget);
      await t.tapAndSettle(find.text('Create “Zed Quill”'));
      expect(find.text('New character'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Zed Quill'), findsOneWidget, reason: 'name is pre-filled');
    });

    testWidgets('shows a skeleton while loading', (t) async {
      await pumpHearth(t, latency: const Duration(milliseconds: 500), settle: false);
      await t.pump(const Duration(milliseconds: 100));
      expect(find.byType(HomeSkeleton), findsOneWidget);
      await t.pumpAndSettle();
      expect(find.byType(HomeSkeleton), findsNothing);
      expect(find.text('CONTINUE CHATTING'), findsOneWidget);
    });

    testWidgets('first run: "Your first story starts here" → Meet the sample characters', (t) async {
      await pumpHearth(t, scenario: MockScenario.empty);
      expect(find.text('Your first story starts here'), findsOneWidget);
      expect(find.text('Create my own'), findsOneWidget);
      await t.tapAndSettle(find.text('Meet the sample characters'));
      expect(find.text('CONTINUE CHATTING'), findsOneWidget);
    });

    testWidgets('offline: "Can’t reach Hearth right now" and Try again recovers', (t) async {
      final h = await pumpHearth(t, scenario: MockScenario.offline);
      expect(find.text('Can’t reach Hearth right now'), findsOneWidget);
      await t.tapAndSettle(find.text('Try again'));
      expect(find.text('Can’t reach Hearth right now'), findsOneWidget, reason: 'still offline');
      h.container.read(mockScenarioProvider.notifier).state = MockScenario.normal;
      await t.pumpAndSettle();
      expect(find.text('CONTINUE CHATTING'), findsOneWidget);
    });

    testWidgets('layout holds at 200% text on a 360dp phone', (t) async {
      await pumpHearth(t, textScale: 2);
      expect(t.takeException(), isNull);
      await t.drag(find.byType(Scrollable).first, const Offset(0, -2500));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    });
  });

  group('Character details', () {
    testWidgets('shows the profile: name, description, tags, universe, journal', (t) async {
      final h = await pumpHearth(t);
      await h.push('/characters/vesper');
      expect(find.text('Vesper Hale'), findsOneWidget);
      expect(find.textContaining('weary lighthouse keeper'), findsOneWidget);
      for (final tag in ['Mystery', 'Slow burn', 'Gothic']) {
        expect(find.text(tag), findsOneWidget);
      }
      expect(find.text('The Saltmarsh Coast'), findsOneWidget);
      expect(find.text('Relationship journal'), findsOneWidget);
      expect(find.text('INTRODUCTION'), findsOneWidget);
    });

    testWidgets('the introduction is clamped to 3 lines until Read more', (t) async {
      final h = await pumpHearth(t);
      await h.push('/characters/vesper');
      Text intro() => t.widget<Text>(find.textContaining('Vesper has kept the Saltmarsh light'));
      expect(intro().maxLines, 3);
      await reveal(t, find.text('Read more'));
      await t.tapAndSettle(find.text('Read more'));
      expect(intro().maxLines, isNull);
      await reveal(t, find.text('Show less'));
      await t.tapAndSettle(find.text('Show less'));
      expect(intro().maxLines, 3);
    });

    testWidgets('"More about X" discloses personality and speaking style', (t) async {
      final h = await pumpHearth(t);
      await h.push('/characters/vesper');
      expect(find.textContaining('Guarded, observant', skipOffstage: false), findsNothing);
      await reveal(t, find.text('More about Vesper'));
      await t.tapAndSettle(find.text('More about Vesper'));
      expect(find.textContaining('Guarded, observant', skipOffstage: false), findsOneWidget);
      expect(find.textContaining('Short, plain sentences', skipOffstage: false), findsOneWidget);
    });

    testWidgets('bottom bar: Edit, Start new chat and a Resume link when a chat exists', (t) async {
      final h = await pumpHearth(t);
      await h.push('/characters/vesper');
      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Start new chat'), findsOneWidget);
      expect(find.text('Resume “The letter from the north tide”'), findsOneWidget);
      expect(t.getSize(find.widgetWithText(OutlinedButton, 'Edit')).height, greaterThanOrEqualTo(48));
      expect(t.getSize(find.widgetWithText(FilledButton, 'Start new chat')).height,
          greaterThanOrEqualTo(48));
      await t.tapAndSettle(find.textContaining('Resume “'));
      expect(find.text('Message Vesper…'), findsOneWidget);
    });

    testWidgets('no Resume link for a character you have not chatted with', (t) async {
      final h = await pumpHearth(t);
      await h.push('/characters/iselde');
      expect(find.textContaining('Resume'), findsNothing);
    });

    testWidgets('Edit, universe link and the journal open their screens', (t) async {
      final h = await pumpHearth(t);
      await h.push('/characters/vesper');
      await t.tapAndSettle(find.text('Edit'));
      expect(find.text('Edit character'), findsOneWidget);
      await t.tapAndSettle(tooltip('Close editor'));
      await reveal(t, find.text('The Saltmarsh Coast'));
      await t.tapAndSettle(find.text('The Saltmarsh Coast'));
      expect(find.textContaining('Separate timeline.'), findsOneWidget);
      await t.tapAndSettle(tooltip('Back'));
      await reveal(t, find.text('Relationship journal'));
      await t.tapAndSettle(find.text('Relationship journal'));
      expect(find.text('Relationship journal'), findsOneWidget);
      expect(find.text('Where you are'.toUpperCase()), findsOneWidget);
    });

    testWidgets('a missing character shows a way back', (t) async {
      final h = await pumpHearth(t);
      await h.push('/characters/nobody');
      expect(find.text('We can’t find this character'), findsOneWidget);
    });

    testWidgets('holds at 200% text', (t) async {
      final h = await pumpHearth(t, textScale: 2);
      await h.push('/characters/vesper');
      await t.drag(detailsScroll(), const Offset(0, -1500));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    });
  });
}
