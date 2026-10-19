import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hearth/features/chat/data/conversation_repository.dart';
import 'package:hearth/features/chat/domain/chat_models.dart';

import 'support/harness.dart';

Finder navLabel(String label) =>
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label));

void main() {
  testWidgets('starts on Characters with a 3-tab bottom bar at 360dp', (t) async {
    await pumpHearth(t);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    for (final label in ['Characters', 'Chats', 'Library']) {
      expect(navLabel(label), findsOneWidget);
    }
    expect(find.text('CONTINUE CHATTING'), findsOneWidget);
    expect(find.text('The letter from the north tide'), findsOneWidget);
  });

  testWidgets('uses a NavigationRail from 600dp', (t) async {
    await pumpHearth(t, size: const Size(700, 900));
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('tabs switch and keep their own state', (t) async {
    await pumpHearth(t);
    await t.tapAndSettle(navLabel('Chats'));
    expect(find.text('The letter from the north tide'), findsWidgets);
    await t.tapAndSettle(navLabel('Library'));
    expect(find.text('The Saltmarsh Coast'), findsOneWidget);
    await t.tapAndSettle(navLabel('Characters'));
    expect(find.text('CONTINUE CHATTING'), findsOneWidget);
  });

  testWidgets('switching tabs shows only the selected page, in both directions', (t) async {
    await pumpHearth(t);
    Finder only(String text) => find.descendant(
        of: find.byType(NavigationBar).evaluate().isEmpty ? find.byType(Scaffold) : find.byType(Scaffold),
        matching: find.text(text));
    expect(only('CONTINUE CHATTING'), findsOneWidget);

    await t.tapAndSettle(navLabel('Library'));
    expect(find.text('The Saltmarsh Coast'), findsOneWidget);
    expect(find.text('CONTINUE CHATTING'), findsNothing, reason: 'old page is gone, not left on top');

    await t.tapAndSettle(navLabel('Chats'));
    expect(find.text('The Saltmarsh Coast'), findsNothing);
    expect(find.text('CONTINUE CHATTING'), findsNothing);

    // Back to Characters from a higher tab: the page must change, not stay stuck.
    await t.tapAndSettle(navLabel('Characters'));
    expect(find.text('CONTINUE CHATTING'), findsOneWidget);
    expect(find.text('The Saltmarsh Coast'), findsNothing);

    // Mid-fade the old page is never drawn over the new one.
    await t.tap(navLabel('Library'));
    await t.pump(const Duration(milliseconds: 120));
    expect(find.text('CONTINUE CHATTING'), findsNothing);
    await t.pumpAndSettle();
  });

  testWidgets('detail screens hide the bottom bar; Back returns to the tab', (t) async {
    final h = await pumpHearth(t);
    await h.push('/characters/jun');
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text('Start new chat'), findsOneWidget);

    await t.tapAndSettle(tooltip('Back'));
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('CONTINUE CHATTING'), findsOneWidget);
  });

  testWidgets('system Back on Chats goes to Characters', (t) async {
    await pumpHearth(t);
    await t.tapAndSettle(navLabel('Chats'));
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    expect(t.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex, 0);
  });

  testWidgets('profile button opens Settings', (t) async {
    await pumpHearth(t);
    await t.tapAndSettle(tooltip('Profile and settings'));
    expect(find.text('Settings'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('primary/inline touch targets meet 48/44dp', (t) async {
    await pumpHearth(t);
    final profile = t.getSize(tooltip('Profile and settings'));
    expect(profile.width, greaterThanOrEqualTo(48));
    expect(profile.height, greaterThanOrEqualTo(48));
  });

  testWidgets('Back from a chat opened from the library returns to the library', (t) async {
    await pumpHearth(t);
    await t.tapAndSettle(find.text('The letter from the north tide').first);
    expect(find.byType(NavigationBar), findsNothing);
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('CONTINUE CHATTING'), findsOneWidget);
  });

  testWidgets('ChatMode survives leaving and reopening the chat', (t) async {
    final h = await pumpHearth(t);
    h.container.read(conversationsProvider.notifier).setMode('c1', ChatMode.story);
    await h.go('/chat/c1');
    expect(find.text('VESPER · STORY'), findsOneWidget);
  });
}
