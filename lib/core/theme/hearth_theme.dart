import 'package:flutter/material.dart';

import 'hearth_colors.dart';
import 'hearth_text.dart';
import 'tokens.dart';

/// User-facing theme choice (Settings → Theme).
enum HearthThemeChoice {
  dark('Dark'),
  trueBlack('True black'),
  light('Light'),

  /// Follows the phone: Light when the phone is in light mode, otherwise Dark.
  system('System');

  const HearthThemeChoice(this.label);
  final String label;

  /// The palette for this choice. [system] has no single palette; it returns
  /// Dark here and the app picks Light or Dark from the phone's setting.
  HearthColors get colors => switch (this) {
    HearthThemeChoice.trueBlack => HearthColors.trueBlack,
    HearthThemeChoice.light => HearthColors.light,
    _ => HearthColors.dark,
  };
}

extension HearthThemeContext on BuildContext {
  HearthColors get hc => Theme.of(this).extension<HearthColors>()!;
  HearthText get ht => Theme.of(this).extension<HearthText>()!;
}

abstract final class HearthTheme {
  static ThemeData build(HearthThemeChoice choice) => forColors(choice.colors);

  static ThemeData forColors(HearthColors c) {
    final t = HearthText.from(c);

    final scheme = ColorScheme(
      brightness: c.brightness,
      primary: c.primary,
      onPrimary: c.onPrimary,
      secondary: c.primaryInk,
      onSecondary: c.onInverse,
      surface: c.surface,
      onSurface: c.text,
      onSurfaceVariant: c.textMuted,
      surfaceContainerLowest: c.bg,
      surfaceContainerLow: c.surface,
      surfaceContainer: c.surface,
      surfaceContainerHigh: c.surfaceRaised,
      surfaceContainerHighest: c.surfaceRaised,
      outline: c.outline,
      outlineVariant: c.outline,
      error: c.danger,
      onError: c.onInverse,
      errorContainer: c.dangerFill,
      onErrorContainer: c.onPrimary,
      scrim: c.scrim,
    );

    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(Radii.button),
    );
    const minPrimary = Size(Hit.primary, Hit.primary);
    const minInline = Size(Hit.inline, Hit.inline);

    return ThemeData(
      useMaterial3: true,
      brightness: c.brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.bg,
      canvasColor: c.bg,
      fontFamily: HearthFonts.sans,
      splashFactory: InkRipple.splashFactory,
      textTheme: TextTheme(
        displaySmall: t.display,
        headlineSmall: t.display,
        titleLarge: t.title,
        titleMedium: t.label,
        titleSmall: t.label,
        bodyLarge: t.chat,
        bodyMedium: t.body,
        bodySmall: t.caption,
        labelLarge: t.label,
        labelMedium: t.overline,
        labelSmall: t.caption,
      ).apply(bodyColor: c.text, displayColor: c.text),
      extensions: [c, t],
      appBarTheme: AppBarTheme(
        backgroundColor: c.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: t.title,
        iconTheme: IconThemeData(color: c.text),
      ),
      dividerTheme: DividerThemeData(color: c.outline, space: 1, thickness: 1),
      iconTheme: IconThemeData(color: c.textMuted),
      // Burgundy is fill-only, so text buttons use the rose ink.
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.primaryInk,
          minimumSize: minInline,
          textStyle: t.label,
          shape: buttonShape,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(minPrimary),
          shape: WidgetStatePropertyAll(buttonShape),
          textStyle: WidgetStatePropertyAll(t.label),
          foregroundColor: WidgetStatePropertyAll(c.onPrimary),
          backgroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.disabled)
                ? c.surfaceRaised
                : s.contains(WidgetState.pressed)
                ? c.primaryPressed
                : c.primary,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: minPrimary,
          shape: buttonShape,
          textStyle: t.label,
          foregroundColor: c.text,
          side: BorderSide(color: c.outline),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: minPrimary,
          foregroundColor: c.text,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surface,
        hintStyle: t.body.copyWith(color: c.textSubtle),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Space.lg,
          vertical: Space.md,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.field),
          borderSide: BorderSide(color: c.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.field),
          borderSide: BorderSide(color: c.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.field),
          borderSide: BorderSide(color: c.primaryInk, width: 2),
        ),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: c.primaryInk,
        selectionColor: c.primarySoft,
        selectionHandleColor: c.primaryInk,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: c.primaryInk),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.onPrimary : c.textSubtle,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.primary : c.outline,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: c.primaryInk,
        inactiveTrackColor: c.outline,
        thumbColor: c.primaryInk,
        overlayColor: c.primaryInk.withValues(alpha: 0.16),
        valueIndicatorColor: c.text,
        valueIndicatorTextStyle: t.caption.copyWith(color: c.onInverse),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: c.primarySoft,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => t.caption.copyWith(
            fontWeight: FontWeight.w600,
            color: s.contains(WidgetState.selected) ? c.text : c.textSubtle,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(
            color: s.contains(WidgetState.selected)
                ? c.primaryInk
                : c.textSubtle,
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: c.surface,
        indicatorColor: c.primarySoft,
        selectedIconTheme: IconThemeData(color: c.primaryInk),
        unselectedIconTheme: IconThemeData(color: c.textSubtle),
        selectedLabelTextStyle: t.caption.copyWith(color: c.text),
        unselectedLabelTextStyle: t.caption,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        modalBarrierColor: c.scrim,
        dragHandleColor: c.outline,
        showDragHandle: false,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(Radii.sheet),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.card),
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        },
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.text,
        contentTextStyle: t.body.copyWith(
          color: c.onInverse,
          fontWeight: FontWeight.w500,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.button),
        ),
      ),
    );
  }
}
