import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/hearth_colors.dart';
import 'core/theme/hearth_theme.dart';
import 'core/theme/theme_provider.dart';
import 'core/widgets/refresh.dart';
import 'core/widgets/splash_gate.dart';
import 'features/auth/presentation/sign_in_screen.dart';
import 'features/settings/data/app_prefs.dart';

class HearthApp extends ConsumerWidget {
  const HearthApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final choice = ref.watch(themeChoiceProvider);
    final uiScale = ref.watch(appPrefsProvider.select((p) => p.uiScale));

    // "System" follows the phone between Light and Dark. The dark slot holds
    // True black only when the user picked True black.
    final darkColors = choice == HearthThemeChoice.trueBlack
        ? HearthColors.trueBlack
        : HearthColors.dark;

    return MaterialApp.router(
      title: 'Hearth',
      debugShowCheckedModeBanner: false,
      theme: HearthTheme.forColors(HearthColors.light),
      darkTheme: HearthTheme.forColors(darkColors),
      themeMode: switch (choice) {
        HearthThemeChoice.light => ThemeMode.light,
        HearthThemeChoice.system => ThemeMode.system,
        _ => ThemeMode.dark,
      },
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) {
        // Edge-to-edge with transparent bars (SPEC §8); icons follow the theme.
        final icons = Theme.of(context).brightness == Brightness.dark
            ? Brightness.light
            : Brightness.dark;
        // "App text size" in Settings multiplies the phone's own text size.
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: uiScale == 1
              ? media
              : media.copyWith(
                  textScaler: TextScaler.linear(
                    media.textScaler.scale(1) * uiScale,
                  ),
                ),
          child: AnnotatedRegion<SystemUiOverlayStyle>(
            value: SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              systemNavigationBarColor: Colors.transparent,
              systemNavigationBarContrastEnforced: false,
              statusBarIconBrightness: icons,
              systemNavigationBarIconBrightness: icons,
            ),
            child: SplashGate(
              child: AuthGate(
                child: RefreshOnResume(child: child ?? const SizedBox.shrink()),
              ),
            ),
          ),
        );
      },
    );
  }
}
