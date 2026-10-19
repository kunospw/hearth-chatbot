import 'package:flutter_test/flutter_test.dart';
import 'package:hearth/core/util/greeting.dart';
import 'package:hearth/core/util/throttler.dart';

void main() {
  group('Throttler (60ms)', () {
    testWidgets('first call runs now; calls inside the window collapse into one trailing run',
        (t) async {
      final th = Throttler(const Duration(milliseconds: 60));
      final ran = <int>[];
      th.run(() => ran.add(1));
      expect(ran, [1]);
      th.run(() => ran.add(2));
      th.run(() => ran.add(3));
      th.run(() => ran.add(4));
      expect(ran, [1], reason: 'held back');
      await t.pump(const Duration(milliseconds: 59));
      expect(ran, [1]);
      await t.pump(const Duration(milliseconds: 2));
      expect(ran, [1, 4], reason: 'only the latest trailing call runs');
      th.cancel();
    });

    testWidgets('a steady stream runs at most once per interval', (t) async {
      final th = Throttler(const Duration(milliseconds: 60));
      var runs = 0;
      for (var i = 0; i < 40; i++) {
        th.run(() => runs++);
        await t.pump(const Duration(milliseconds: 10)); // 400ms of chunks
      }
      await t.pump(const Duration(milliseconds: 100));
      expect(runs, inInclusiveRange(6, 8), reason: '400ms / 60ms');
      th.cancel();
    });

    testWidgets('flush delivers the pending call immediately; cancel drops it', (t) async {
      final th = Throttler(const Duration(milliseconds: 60));
      final ran = <int>[];
      th.run(() => ran.add(1));
      th.run(() => ran.add(2));
      th.flush();
      expect(ran, [1, 2]);
      th.run(() => ran.add(3));
      th.run(() => ran.add(4));
      th.cancel();
      await t.pump(const Duration(milliseconds: 200));
      expect(ran, [1, 2, 3]);
    });
  });

  test('greeting follows the time of day', () {
    expect(greetingFor(DateTime(2026, 1, 1, 7)), 'Good morning');
    expect(greetingFor(DateTime(2026, 1, 1, 13)), 'Good afternoon');
    expect(greetingFor(DateTime(2026, 1, 1, 19)), 'Good evening');
    expect(greetingFor(DateTime(2026, 1, 1, 2)), 'Good evening');
  });
}
