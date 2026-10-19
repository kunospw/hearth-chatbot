import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hearth/core/theme/hearth_colors.dart';
import 'package:hearth/core/theme/hearth_text.dart';
import 'package:hearth/core/theme/hearth_theme.dart';
import 'package:hearth/core/theme/tokens.dart';

void main() {
  group('HearthColors', () {
    test('dark matches SPEC §1', () {
      const c = HearthColors.dark;
      expect(c.bg, const Color(0xFF131214));
      expect(c.surface, const Color(0xFF1C1A1D));
      expect(c.primary, const Color(0xFF9A3349));
      expect(c.primaryInk, const Color(0xFFE9A0AE));
      expect(c.primarySoft, const Color(0xFF3B1F27));
      expect(c.dialogue, const Color(0xFFF6EFE9));
      expect(c.narration, const Color(0xFFD9D1CA));
    });

    test('scrim is #080708 at 66%', () {
      final a = HearthColors.dark.scrim;
      expect(a.toARGB32() & 0x00FFFFFF, 0x080708);
      expect(a.a, closeTo(0.66, 0.01));
    });

    test('true black only swaps bg and surface', () {
      final t = HearthColors.trueBlack;
      expect(t.bg, const Color(0xFF000000));
      expect(t.surface, const Color(0xFF121112));
      expect(t.surfaceRaised, HearthColors.dark.surfaceRaised);
      expect(t.primary, HearthColors.dark.primary);
    });
  });

  group('tokens', () {
    test('spacing, radii and hit targets match SPEC', () {
      expect([Space.xs, Space.sm, Space.md, Space.lg, Space.gutter, Space.xl, Space.xxl],
          [4, 8, 12, 16, 20, 24, 32]);
      expect([Radii.field, Radii.button, Radii.card, Radii.sheet], [12, 14, 18, 26]);
      expect(Hit.primary, 48);
      expect(Hit.inline, 44);
      expect(Reading.chatSize, (min: 14.0, def: 16.0, max: 22.0));
      expect(Reading.storySize, (min: 15.0, def: 19.0, max: 26.0));
    });
  });

  group('HearthText', () {
    final t = HearthText.from(HearthColors.dark);

    test('roles use the right family, size and line height', () {
      expect(t.display.fontFamily, HearthFonts.serif);
      expect((t.display.fontSize, t.display.height), (30.0, 1.15));
      expect((t.title.fontSize, t.title.height), (19.0, 1.25));
      expect(t.story.fontFamily, HearthFonts.serif);
      expect((t.story.fontSize, t.story.height), (19.0, 1.72));
      expect(t.chat.fontFamily, HearthFonts.sans);
      expect((t.chat.fontSize, t.chat.height), (16.0, 1.62));
      expect(t.label.fontWeight, FontWeight.w600);
      expect(t.overline.letterSpacing, closeTo(13 * 0.06, 1e-9));
    });

    test('storyStyle and chatStyle clamp to the user-adjustable range', () {
      expect(t.storyStyle(size: 40).fontSize, 26);
      expect(t.storyStyle(size: 5).fontSize, 15);
      expect(t.chatStyle(size: 40).fontSize, 22);
      expect(t.chatStyle(size: 5).fontSize, 14);
      expect(t.chatStyle(lineHeight: 1.8).height, 1.8);
    });
  });

  testWidgets('theme exposes both extensions and keeps burgundy off text buttons',
      (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(MaterialApp(
      theme: HearthTheme.build(HearthThemeChoice.trueBlack),
      home: Builder(builder: (c) {
        ctx = c;
        return const SizedBox();
      }),
    ));
    expect(ctx.hc.bg, const Color(0xFF000000));
    expect(ctx.ht.display.fontFamily, HearthFonts.serif);
    final fg = Theme.of(ctx).textButtonTheme.style!.foregroundColor!.resolve({});
    expect(fg, HearthColors.dark.primaryInk);
  });
}
