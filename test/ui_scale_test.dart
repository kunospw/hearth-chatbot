import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hearth/features/settings/data/app_prefs.dart';

import 'support/harness.dart';

void main() {
  group('App text size', () {
    testWidgets('Settings → App text size scales the whole app and is remembered', (t) async {
      final h = await pumpHearth(t);
      await h.push('/settings');
      final probe = find.text('Appearance'.toUpperCase());
      final before = t.getSize(probe).height;
      await t.tapAndSettle(find.text('Biggest'));
      expect(h.container.read(appPrefsProvider).uiScale, 1.3);
      expect(t.getSize(probe).height, greaterThan(before));
      await t.tapAndSettle(find.text('Normal'));
      expect(t.getSize(probe).height, before);
    });

    testWidgets('a saved size applies at start-up', (t) async {
      await pumpHearth(t, prefs: {'app.uiScale': 1.3});
      final ctx = t.element(find.byType(Scaffold).first);
      expect(MediaQuery.textScalerOf(ctx).scale(10), closeTo(13, 0.01));
    });
  });

  group('Back stays pinned while scrolling', () {
    Future<void> scrollAway(WidgetTester t) async {
      await t.drag(find.byType(Scrollable).last, const Offset(0, -600), warnIfMissed: false);
      await t.pumpAndSettle();
    }

    testWidgets('character details', (t) async {
      final h = await pumpHearth(t);
      await h.push('/characters/vesper');
      await scrollAway(t);
      final back = tooltip('Back');
      expect(back, findsOneWidget);
      expect(t.getTopLeft(back).dy, lessThan(60));
      await t.tapAndSettle(back);
      expect(find.text('Start new chat'), findsNothing);
    });

    testWidgets('universe: Back and Edit', (t) async {
      final h = await pumpHearth(t);
      await h.push('/universes/saltmarsh');
      await scrollAway(t);
      expect(t.getTopLeft(tooltip('Back')).dy, lessThan(60));
      expect(t.getTopLeft(find.text('Edit')).dy, lessThan(70));
    });
  });
}
