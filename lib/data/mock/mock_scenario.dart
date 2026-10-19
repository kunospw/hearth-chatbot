import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Which situation the mock repositories simulate. Switchable from the debug
/// design reference so empty / offline states can be tried on a device.
enum MockScenario {
  normal('Normal'),
  empty('First run'),
  offline('Offline');

  const MockScenario(this.label);
  final String label;
}

final mockScenarioProvider = StateProvider<MockScenario>(
  (ref) => MockScenario.normal,
);

/// One-shot switch (from the debug design reference): the next reply fails as
/// if the device were offline, so the inline error card can be tried.
final mockFailNextReplyProvider = StateProvider<bool>((ref) => false);

/// How long mock list loads take, so skeletons are visible. Tests build the
/// repositories directly (zero latency) or override this.
final mockLatencyProvider = Provider<Duration>(
  (ref) => const Duration(milliseconds: 600),
);

/// Thrown by repositories and the reply service when the device can't reach
/// the server.
class OfflineException implements Exception {
  const OfflineException();

  @override
  String toString() => 'OfflineException';
}
