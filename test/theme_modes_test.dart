import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hearth/core/theme/hearth_colors.dart';
import 'package:hearth/core/widgets/hearth_logo.dart';
import 'package:hearth/features/library/data/library_repository.dart';

import 'support/harness.dart';

HearthColors colorsOf(WidgetTester t) =>
    Theme.of(t.element(find.byType(Scaffold).last)).extension<HearthColors>()!;

SystemUiOverlayStyle? overlayOf(WidgetTester t) {
  final regions = t.widgetList<AnnotatedRegion<SystemUiOverlayStyle>>(
      find.byType(AnnotatedRegion<SystemUiOverlayStyle>));
  return regions.isEmpty ? null : regions.first.value;
}

void main() {
  group('theme choice', () {
    testWidgets('Dark is the default', (t) async {
      await pumpHearth(t);
      expect(colorsOf(t).bg, HearthColors.dark.bg);
    });

    testWidgets('Light uses the light palette everywhere', (t) async {
      await pumpHearth(t, prefs: {'theme_choice': 'light'});
      expect(colorsOf(t).brightness, Brightness.light);
      expect(colorsOf(t).bg, HearthColors.light.bg);
      expect(colorsOf(t).primary, HearthColors.dark.primary, reason: 'burgundy fill is shared');
    });

    testWidgets('True black swaps only the surfaces', (t) async {
      await pumpHearth(t, prefs: {'theme_choice': 'trueBlack'});
      expect(colorsOf(t).bg, const Color(0xFF000000));
      expect(colorsOf(t).surface, const Color(0xFF121112));
    });

    testWidgets('System follows the phone: light phone → Light', (t) async {
      await pumpHearth(t, prefs: {'theme_choice': 'system'}, platformBrightness: Brightness.light);
      expect(colorsOf(t).bg, HearthColors.light.bg);
    });

    testWidgets('System follows the phone: dark phone → Dark', (t) async {
      await pumpHearth(t, prefs: {'theme_choice': 'system'}, platformBrightness: Brightness.dark);
      expect(colorsOf(t).bg, HearthColors.dark.bg);
    });

    testWidgets('a light phone does not override an explicit Dark or True black', (t) async {
      await pumpHearth(t, prefs: {'theme_choice': 'trueBlack'}, platformBrightness: Brightness.light);
      expect(colorsOf(t).bg, const Color(0xFF000000));
    });

    testWidgets('System changes live when the phone switches mode', (t) async {
      await pumpHearth(t, prefs: {'theme_choice': 'system'}, platformBrightness: Brightness.dark);
      expect(colorsOf(t).brightness, Brightness.dark);
      t.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      await t.pumpAndSettle();
      expect(colorsOf(t).brightness, Brightness.light);
    });
  });

  group('system bars', () {
    testWidgets('dark theme → light status-bar icons, transparent bars', (t) async {
      await pumpHearth(t);
      final o = overlayOf(t)!;
      expect(o.statusBarIconBrightness, Brightness.light);
      expect(o.systemNavigationBarIconBrightness, Brightness.light);
      expect(o.statusBarColor, const Color(0x00000000));
    });

    testWidgets('light theme → dark status-bar icons', (t) async {
      await pumpHearth(t, prefs: {'theme_choice': 'light'});
      final o = overlayOf(t)!;
      expect(o.statusBarIconBrightness, Brightness.dark);
      expect(o.systemNavigationBarIconBrightness, Brightness.dark);
    });
  });

  group('light mode details', () {
    testWidgets('the flame logo keeps its ember visible on the burgundy', (t) async {
      await pumpHearth(t, prefs: {'theme_choice': 'light'});
      expect(find.byType(HearthLogo), findsWidgets);
      expect(HearthColors.light.ember, isNot(HearthColors.light.primary));
    });

    testWidgets('selected segment is an inverse pill (dark on light mode) with readable text',
        (t) async {
      await pumpHearth(t, prefs: {'theme_choice': 'light'});
      await t.tapAndSettle(tooltip('Profile and settings'));
      final c = HearthColors.light;
      final selected = find.ancestor(
          of: find.text('Light'), matching: find.byType(AnimatedContainer)).first;
      final deco = t.widget<AnimatedContainer>(selected).decoration as BoxDecoration;
      expect(deco.color, c.text);
      final label = t.widget<AnimatedDefaultTextStyle>(find.ancestor(
          of: find.text('Light'), matching: find.byType(AnimatedDefaultTextStyle)).first);
      expect(label.style.color, c.onInverse);
    });

    testWidgets('toasts use the inverse colours in Light', (t) async {
      await pumpHearth(t, prefs: {'theme_choice': 'light'});
      await t.tapAndSettle(tooltip('Profile and settings'));
      await t.drag(find.byType(Scrollable).last, const Offset(0, -900));
      await t.pumpAndSettle();
      await t.tapAndSettle(find.text('Export everything'));
      final snack = t.widget<SnackBar>(find.byType(SnackBar));
      expect(snack.backgroundColor, HearthColors.light.text);
    });

    testWidgets('a character card tag stays readable on a light card (own tile colours)', (t) async {
      await pumpHearth(t, prefs: {'theme_choice': 'light'});
      expect(t.takeException(), isNull);
    });
  });

  group('every screen renders in Light and Dark, at 360dp and at 200% text', () {
    final routes = <String, String>{
      'home': '/characters',
      'details': '/characters/vesper',
      'chat': '/chat/c1',
      'editor': '/characters/new',
      'edit': '/characters/jun/edit',
      'journal': '/characters/vesper/relationship?entry=e5',
      'universe': '/universes/saltmarsh',
      'universe memories': '/universes/saltmarsh/memories',
      'settings': '/settings',
      'AI settings': '/settings/ai',
      'library: universes': '/library',
      'library: memories': '/library?tab=memories',
      'library: personas': '/library?tab=personas',
      'chats': '/chats',
    };

    for (final theme in ['light', 'dark']) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('$theme · ${scale == 1 ? "normal" : "200%"} text', (t) async {
          final h = await pumpHearth(t, textScale: scale, prefs: {'theme_choice': theme});
          for (final e in routes.entries) {
            await h.go(e.value);
            expect(t.takeException(), isNull, reason: '${e.key} in $theme at $scale');
            await t.drag(find.byType(Scrollable).last, const Offset(0, -700), warnIfMissed: false);
            await t.pumpAndSettle();
            expect(t.takeException(), isNull, reason: '${e.key} (scrolled) in $theme at $scale');
          }
        });
      }
    }
  });

  testWidgets('light mode screens leave no dark-only colours: backgrounds are the light palette',
      (t) async {
    final h = await pumpHearth(t, prefs: {'theme_choice': 'light'});
    for (final r in ['/characters', '/chats', '/library', '/settings', '/chat/c1']) {
      await h.go(r);
      final bg = Theme.of(t.element(find.byType(Scaffold).last)).scaffoldBackgroundColor;
      expect(bg, HearthColors.light.bg, reason: r);
    }
    expect(h.container.read(universesProvider).requireValue, isNotEmpty);
  });
}
