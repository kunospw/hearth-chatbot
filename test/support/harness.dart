import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hearth/app.dart';
import 'package:hearth/core/router/app_router.dart';
import 'package:hearth/core/theme/theme_provider.dart';
import 'package:hearth/data/mock/mock_scenario.dart';
import 'package:hearth/features/chat/data/conversation_repository.dart';
import 'package:hearth/features/chat/data/reply_streaming_service.dart';
import 'package:hearth/features/chat/domain/chat_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Pumps the whole app on mock data with fast, deterministic timings.
class Harness {
  Harness(this.t, this.container);

  final WidgetTester t;
  final ProviderContainer container;

  GoRouter get router => container.read(routerProvider);

  Future<void> go(String location) async {
    router.go(location);
    await t.pumpAndSettle();
  }

  Future<void> push(String location) async {
    router.push(location);
    await t.pumpAndSettle();
  }

  /// Lets a streamed reply finish.
  Future<void> settle() => t.pumpAndSettle();
}

Future<Harness> pumpHearth(
  WidgetTester t, {
  Size size = const Size(360, 800),
  double textScale = 1,
  MockScenario scenario = MockScenario.normal,
  Duration latency = Duration.zero,
  Map<String, Object> prefs = const {},
  bool settle = true,
  List<Override> overrides = const [],
  Brightness? platformBrightness,
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final sp = await SharedPreferences.getInstance();
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  t.platformDispatcher.textScaleFactorTestValue = textScale;
  if (platformBrightness != null) {
    t.platformDispatcher.platformBrightnessTestValue = platformBrightness;
  }
  addTearDown(() {
    t.view.reset();
    t.platformDispatcher.clearTextScaleFactorTestValue();
    t.platformDispatcher.clearPlatformBrightnessTestValue();
  });

  await t.pumpWidget(ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(sp),
      mockLatencyProvider.overrideWithValue(latency),
      mockScenarioProvider.overrideWith((ref) => scenario),
      replyStreamingServiceProvider.overrideWith((ref) => FakeReplyStreamingService(
            thinkingDelay: const Duration(milliseconds: 120),
            tick: const Duration(milliseconds: 40),
            wordsPerTick: 6,
            isOffline: () {
              if (ref.read(mockScenarioProvider) == MockScenario.offline) return true;
              if (ref.read(mockFailNextReplyProvider)) {
                ref.read(mockFailNextReplyProvider.notifier).state = false;
                return true;
              }
              return false;
            },
          )),
      ...overrides,
    ],
    child: const HearthApp(),
  ));
  if (settle) await t.pumpAndSettle();
  final container = ProviderScope.containerOf(t.element(find.byType(HearthApp)));
  return Harness(t, container);
}

/// Records what the app copies to the clipboard.
List<String> captureClipboard(WidgetTester t) {
  final copied = <String>[];
  t.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
    if (call.method == 'Clipboard.setData') {
      copied.add((call.arguments as Map)['text'] as String);
    }
    return null;
  });
  addTearDown(() => t.binding.defaultBinaryMessenger
      .setMockMethodCallHandler(SystemChannels.platform, null));
  return copied;
}

/// Taps and settles.
extension TapSettle on WidgetTester {
  Future<void> tapAndSettle(Finder f, {bool warn = true}) async {
    await tap(f, warnIfMissed: warn);
    await pumpAndSettle();
  }
}

Finder tooltip(String message) => find.byTooltip(message);

/// The conversation with this id, straight from the live provider state.
Conversation convOf(Harness h, String id) => h.container.read(conversationProvider(id))!;
