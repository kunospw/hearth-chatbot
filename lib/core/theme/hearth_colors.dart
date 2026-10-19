import 'package:flutter/material.dart';

/// Midnight Editorial colour tokens (SPEC §1).
///
/// Burgundy [primary] is a **fill only**. Use [primaryInk] for links,
/// focus rings and highlights.
@immutable
class HearthColors extends ThemeExtension<HearthColors> {
  const HearthColors({
    required this.bg,
    required this.surface,
    required this.surfaceRaised,
    required this.outline,
    required this.text,
    required this.textMuted,
    required this.textSubtle,
    required this.primary,
    required this.primaryPressed,
    required this.primaryInk,
    required this.primarySoft,
    required this.onPrimary,
    required this.pin,
    required this.danger,
    required this.dangerFill,
    required this.ok,
    required this.scrim,
    required this.dialogue,
    required this.narration,
    required this.onInverse,
    required this.inverseAccent,
    required this.onScrim,
    required this.ember,
    required this.brightness,
    required this.meterTrust,
    required this.meterAffection,
    required this.meterAttraction,
    required this.meterTension,
  });

  final Color bg;
  final Color surface;
  final Color surfaceRaised;
  final Color outline;
  final Color text;
  final Color textMuted;
  final Color textSubtle;
  final Color primary;
  final Color primaryPressed;
  final Color primaryInk;
  final Color primarySoft;
  final Color onPrimary;
  final Color pin;

  /// Destructive text colour. Use [dangerFill] for filled destructive buttons.
  final Color danger;
  final Color dangerFill;
  final Color ok;

  /// Already includes the 66% alpha.
  final Color scrim;

  /// Roleplay text: "dialogue" is brightest, narration sits between.
  final Color dialogue;
  final Color narration;

  /// Content on an *inverse* surface, i.e. one filled with [text] (the
  /// selected segment, toasts, the new-reply pill). Dark on dark theme's light
  /// pill, light on light theme's dark pill.
  final Color onInverse;

  /// Accent for an action (like Undo) sitting on an inverse surface.
  final Color inverseAccent;

  /// Icons and text over a photo or [scrim].
  final Color onScrim;

  /// The glowing centre of the flame logo (sits on a [primary] fill).
  final Color ember;

  final Brightness brightness;

  /// Relationship journal meters (non-text; ≥3:1 on the surface).
  final Color meterTrust;
  final Color meterAffection;
  final Color meterAttraction;
  final Color meterTension;

  static const HearthColors dark = HearthColors(
    bg: Color(0xFF131214),
    surface: Color(0xFF1C1A1D),
    surfaceRaised: Color(0xFF262327),
    outline: Color(0xFF3A3539),
    text: Color(0xFFEEE7E1),
    textMuted: Color(0xFFB3AAA3),
    textSubtle: Color(0xFF9C948D),
    primary: Color(0xFF9A3349),
    primaryPressed: Color(0xFF7E2739),
    primaryInk: Color(0xFFE9A0AE),
    primarySoft: Color(0xFF3B1F27),
    onPrimary: Color(0xFFFFF6F3),
    pin: Color(0xFFF2CF9A),
    danger: Color(0xFFEF8A78),
    dangerFill: Color(0xFF8E2B22),
    ok: Color(0xFF8DBF95),
    scrim: Color(0xA8080708),
    dialogue: Color(0xFFF6EFE9),
    narration: Color(0xFFD9D1CA),
    onInverse: Color(0xFF1A1719),
    inverseAccent: Color(0xFF7E2739),
    onScrim: Color(0xFFEEE7E1),
    ember: Color(0xFFE9A0AE),
    brightness: Brightness.dark,
    meterTrust: Color(0xFFBFD9D6),
    meterAffection: Color(0xFFE9A0AE),
    meterAttraction: Color(0xFFF2CF9A),
    meterTension: Color(0xFFEF8A78),
  );

  /// The light theme: warm paper, the same burgundy fills, the same type.
  /// Contrast is checked in test/contrast_test.dart.
  static const HearthColors light = HearthColors(
    bg: Color(0xFFF6F1EB),
    surface: Color(0xFFFFFCF8),
    surfaceRaised: Color(0xFFEDE5DC),
    outline: Color(0xFFD8CEC4),
    text: Color(0xFF241F22),
    textMuted: Color(0xFF5B5258),
    textSubtle: Color(0xFF6A6065),
    primary: Color(0xFF9A3349),
    primaryPressed: Color(0xFF7E2739),
    primaryInk: Color(0xFF8C2A40),
    primarySoft: Color(0xFFF2DDE2),
    onPrimary: Color(0xFFFFF6F3),
    pin: Color(0xFF8A5A00),
    danger: Color(0xFFB3342A),
    dangerFill: Color(0xFF8E2B22),
    ok: Color(0xFF2E7D45),
    scrim: Color(0xB31A1518),
    dialogue: Color(0xFF14100E),
    narration: Color(0xFF3A3236),
    onInverse: Color(0xFFF6F1EB),
    inverseAccent: Color(0xFFF4B6C2),
    onScrim: Color(0xFFFFF6F3),
    ember: Color(0xFFF2B3BF),
    brightness: Brightness.light,
    meterTrust: Color(0xFF3E7F7A),
    meterAffection: Color(0xFFB04460),
    meterAttraction: Color(0xFF9A6B14),
    meterTension: Color(0xFFB3342A),
  );

  /// "True black": bg → #000000, surface → #121112 (SPEC §1).
  static final HearthColors trueBlack = dark.copyWith(
    bg: const Color(0xFF000000),
    surface: const Color(0xFF121112),
  );

  @override
  HearthColors copyWith({
    Color? bg,
    Color? surface,
    Color? surfaceRaised,
    Color? outline,
    Color? text,
    Color? textMuted,
    Color? textSubtle,
    Color? primary,
    Color? primaryPressed,
    Color? primaryInk,
    Color? primarySoft,
    Color? onPrimary,
    Color? pin,
    Color? danger,
    Color? dangerFill,
    Color? ok,
    Color? scrim,
    Color? dialogue,
    Color? narration,
    Color? onInverse,
    Color? inverseAccent,
    Color? onScrim,
    Color? ember,
    Brightness? brightness,
    Color? meterTrust,
    Color? meterAffection,
    Color? meterAttraction,
    Color? meterTension,
  }) {
    return HearthColors(
      bg: bg ?? this.bg,
      surface: surface ?? this.surface,
      surfaceRaised: surfaceRaised ?? this.surfaceRaised,
      outline: outline ?? this.outline,
      text: text ?? this.text,
      textMuted: textMuted ?? this.textMuted,
      textSubtle: textSubtle ?? this.textSubtle,
      primary: primary ?? this.primary,
      primaryPressed: primaryPressed ?? this.primaryPressed,
      primaryInk: primaryInk ?? this.primaryInk,
      primarySoft: primarySoft ?? this.primarySoft,
      onPrimary: onPrimary ?? this.onPrimary,
      pin: pin ?? this.pin,
      danger: danger ?? this.danger,
      dangerFill: dangerFill ?? this.dangerFill,
      ok: ok ?? this.ok,
      scrim: scrim ?? this.scrim,
      dialogue: dialogue ?? this.dialogue,
      narration: narration ?? this.narration,
      onInverse: onInverse ?? this.onInverse,
      inverseAccent: inverseAccent ?? this.inverseAccent,
      onScrim: onScrim ?? this.onScrim,
      ember: ember ?? this.ember,
      brightness: brightness ?? this.brightness,
      meterTrust: meterTrust ?? this.meterTrust,
      meterAffection: meterAffection ?? this.meterAffection,
      meterAttraction: meterAttraction ?? this.meterAttraction,
      meterTension: meterTension ?? this.meterTension,
    );
  }

  @override
  HearthColors lerp(ThemeExtension<HearthColors>? other, double t) {
    if (other is! HearthColors) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return HearthColors(
      bg: l(bg, other.bg),
      surface: l(surface, other.surface),
      surfaceRaised: l(surfaceRaised, other.surfaceRaised),
      outline: l(outline, other.outline),
      text: l(text, other.text),
      textMuted: l(textMuted, other.textMuted),
      textSubtle: l(textSubtle, other.textSubtle),
      primary: l(primary, other.primary),
      primaryPressed: l(primaryPressed, other.primaryPressed),
      primaryInk: l(primaryInk, other.primaryInk),
      primarySoft: l(primarySoft, other.primarySoft),
      onPrimary: l(onPrimary, other.onPrimary),
      pin: l(pin, other.pin),
      danger: l(danger, other.danger),
      dangerFill: l(dangerFill, other.dangerFill),
      ok: l(ok, other.ok),
      scrim: l(scrim, other.scrim),
      dialogue: l(dialogue, other.dialogue),
      narration: l(narration, other.narration),
      onInverse: l(onInverse, other.onInverse),
      inverseAccent: l(inverseAccent, other.inverseAccent),
      onScrim: l(onScrim, other.onScrim),
      ember: l(ember, other.ember),
      brightness: t < 0.5 ? brightness : other.brightness,
      meterTrust: l(meterTrust, other.meterTrust),
      meterAffection: l(meterAffection, other.meterAffection),
      meterAttraction: l(meterAttraction, other.meterAttraction),
      meterTension: l(meterTension, other.meterTension),
    );
  }
}
