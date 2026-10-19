import 'dart:math' as math;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hearth/core/theme/hearth_colors.dart';
import 'package:hearth/data/mock/mock_data.dart';

double _lin(double v) => v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
double _lum(Color c) => 0.2126 * _lin(c.r) + 0.7152 * _lin(c.g) + 0.0722 * _lin(c.b);

/// WCAG contrast ratio of [fg] on [bg] (alpha of [fg] is composited first).
double contrast(Color fg, Color bg) {
  final f = Color.alphaBlend(fg, bg);
  final a = _lum(f), b = _lum(bg);
  final hi = math.max(a, b), lo = math.min(a, b);
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  final palettes = {
    'dark': HearthColors.dark,
    'trueBlack': HearthColors.trueBlack,
    'light': HearthColors.light,
  };

  for (final e in palettes.entries) {
    final c = e.value;
    group('${e.key} palette contrast', () {
      void atLeast(String name, Color fg, Color bg, double min) {
        test('$name ≥ $min:1', () => expect(contrast(fg, bg), greaterThanOrEqualTo(min)));
      }

      for (final (bgName, bg) in [('bg', c.bg), ('surface', c.surface)]) {
        atLeast('text on $bgName', c.text, bg, 7);
        atLeast('textMuted on $bgName', c.textMuted, bg, 4.5);
        atLeast('textSubtle on $bgName', c.textSubtle, bg, 4.5);
        atLeast('primaryInk (links, focus) on $bgName', c.primaryInk, bg, 4.5);
        atLeast('danger text on $bgName', c.danger, bg, 4.5);
        atLeast('ok text on $bgName', c.ok, bg, 4.5);
        atLeast('dialogue on $bgName', c.dialogue, bg, 7);
        atLeast('narration on $bgName', c.narration, bg, 7);
        atLeast('pin icon on $bgName (non-text)', c.pin, bg, 3);
      }
      atLeast('text on raised surface', c.text, c.surfaceRaised, 7);
      atLeast('textMuted on raised surface', c.textMuted, c.surfaceRaised, 4.5);
      atLeast('text on the soft bubble', c.text, c.primarySoft, 7);
      atLeast('onPrimary on primary fill', c.onPrimary, c.primary, 4.5);
      atLeast('onPrimary on pressed primary', c.onPrimary, c.primaryPressed, 4.5);
      atLeast('onPrimary on danger fill', c.onPrimary, c.dangerFill, 4.5);
      atLeast('onInverse on the inverse pill', c.onInverse, c.text, 7);
      atLeast('Undo accent on the inverse pill', c.inverseAccent, c.text, 4.5);
      atLeast('ember on the flame', c.ember, c.primary, 3);
      atLeast('onScrim over the scrim on a bright photo', c.onScrim,
          Color.alphaBlend(c.scrim, const Color(0xFFFFFFFF)), 4.5);
      atLeast('outline against bg (non-text)', c.outline, c.bg, 1.15);
      for (final (name, m) in [
        ('trust meter', c.meterTrust),
        ('affection meter', c.meterAffection),
        ('attraction meter', c.meterAttraction),
        ('tension meter', c.meterTension),
      ]) {
        atLeast('$name on the surface (non-text)', m, c.surface, 3);
        atLeast('$name on the track (non-text)', m, c.surfaceRaised, 2.5);
      }
    });
  }

  test('the dark palette keeps the spec ratios on bg (15.6, 8.4, 6.3)', () {
    final c = HearthColors.dark;
    // SPEC §1 quotes 15.6:1; its own hex values (#EEE7E1 on #131214) give 15.3.
    expect(contrast(c.text, c.bg), closeTo(15.6, 0.5));
    expect(contrast(c.textMuted, c.bg), closeTo(8.4, 0.3));
    expect(contrast(c.textSubtle, c.bg), closeTo(6.3, 0.3));
  });

  test('every character\'s ink reads on its tile (≥4.5:1, SPEC §1)', () {
    for (final ch in MockData.characters) {
      expect(contrast(ch.ink, ch.tile), greaterThanOrEqualTo(4.5), reason: ch.name);
    }
    for (final s in MockData.swatches) {
      expect(contrast(s.ink, s.tile), greaterThanOrEqualTo(4.5), reason: s.label);
    }
  });

  test('burgundy stays a fill: in every palette the link ink is not the fill colour', () {
    for (final c in palettes.values) {
      expect(c.primaryInk, isNot(c.primary));
    }
  });
}
