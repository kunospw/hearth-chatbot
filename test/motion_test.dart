import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hearth/core/theme/hearth_theme.dart';
import 'package:hearth/core/widgets/hearth_logo.dart';
import 'package:hearth/core/widgets/motion_widgets.dart';
import 'package:hearth/core/widgets/splash_gate.dart';

Widget _app(Widget child, {bool disableAnimations = false}) => MaterialApp(
      theme: HearthTheme.build(HearthThemeChoice.dark),
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: disableAnimations),
        child: child,
      ),
    );

void main() {
  testWidgets('splash shows the logo, then disappears', (tester) async {
    await tester.pumpWidget(_app(const SplashGate(child: Text('home'))));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(HearthLogo), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    expect(find.byType(HearthLogo), findsNothing);
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('splash is skipped when animations are removed', (tester) async {
    await tester.pumpWidget(
        _app(const SplashGate(child: Text('home')), disableAnimations: true));
    expect(find.byType(HearthLogo), findsNothing);
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('EntranceFade starts transparent and ends opaque', (tester) async {
    await tester.pumpWidget(_app(const EntranceFade(child: Text('x'))));
    expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 0);
    await tester.pumpAndSettle();
    expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 1);
  });

  testWidgets('EntranceFade does nothing when animations are removed', (tester) async {
    await tester.pumpWidget(
        _app(const EntranceFade(child: Text('x')), disableAnimations: true));
    expect(find.byType(Opacity), findsNothing);
  });

  testWidgets('PressScale shrinks while pressed and restores', (tester) async {
    await tester.pumpWidget(_app(const Center(child: PressScale(child: SizedBox.square(dimension: 100)))));
    final g = await tester.startGesture(tester.getCenter(find.byType(PressScale)));
    await tester.pumpAndSettle();
    expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, lessThan(1));
    await g.up();
    await tester.pumpAndSettle();
    expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 1);
  });

  test('the flame stays inside its box at every size and is centred', () {
    for (final size in [16.0, 24.0, 48.0, 88.0]) {
      final r = HearthLogo.flameBoundsIn(size);
      expect(r.left, greaterThanOrEqualTo(0), reason: '$size');
      expect(r.top, greaterThanOrEqualTo(0), reason: '$size');
      expect(r.right, lessThanOrEqualTo(size), reason: '$size');
      expect(r.bottom, lessThanOrEqualTo(size), reason: '$size');
      expect((r.center.dx - size / 2).abs(), lessThan(size * 0.03));
      expect((r.center.dy - size / 2).abs(), lessThan(size * 0.03));
    }
  });
}
