import 'package:flutter/material.dart';

import '../theme/hearth_theme.dart';
import '../theme/tokens.dart';

/// The Hearth flame: a burgundy fill with a rose-ink ember. Painted from the
/// theme so it follows Dark / True black. Geometry matches
/// `assets/brand/hearth_mark.svg` (512 × 512 viewBox).
class HearthLogo extends StatelessWidget {
  const HearthLogo({
    super.key,
    this.size = Sizes.avatar,
    this.semanticLabel = 'Hearth',
  });

  final double size;
  final String? semanticLabel;

  /// Where the flame is painted inside a [size] × [size] box (for tests).
  static Rect flameBoundsIn(double size) => _FlamePainter.flameBoundsIn(size);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      image: true,
      child: ExcludeSemantics(
        child: CustomPaint(
          size: Size.square(size),
          painter: _FlamePainter(
            flame: context.hc.primary,
            ember: context.hc.ember,
          ),
        ),
      ),
    );
  }
}

class _FlamePainter extends CustomPainter {
  _FlamePainter({required this.flame, required this.ember});

  final Color flame;
  final Color ember;

  static Path _outer() => Path()
    ..moveTo(256, 56)
    ..cubicTo(300, 120, 392, 190, 392, 300)
    ..cubicTo(392, 376, 332, 440, 256, 440)
    ..cubicTo(180, 440, 120, 376, 120, 300)
    ..cubicTo(120, 236, 160, 196, 188, 164)
    ..cubicTo(196, 196, 214, 212, 226, 214)
    ..cubicTo(214, 150, 232, 100, 256, 56)
    ..close();

  static Path _inner() => Path()
    ..moveTo(256, 250)
    ..cubicTo(282, 286, 320, 310, 320, 356)
    ..cubicTo(320, 394, 292, 420, 256, 420)
    ..cubicTo(220, 420, 192, 394, 192, 356)
    ..cubicTo(192, 320, 226, 296, 256, 250)
    ..close();

  // The flame is 272 wide × 384 tall (x 120–392, y 56–440). Fit it into a
  // 400 × 400 square centred on it, so it always stays inside its box.
  static const _left = 56.0, _top = 48.0, _extent = 400.0;

  /// Where the flame lands inside a [size] × [size] box (for tests).
  static Rect flameBoundsIn(double size) {
    final s = size / _extent;
    final r = _outer().getBounds().shift(const Offset(-_left, -_top));
    return Rect.fromLTRB(r.left * s, r.top * s, r.right * s, r.bottom * s);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide / _extent;
    canvas
      ..scale(s)
      ..translate(-_left, -_top);
    canvas.drawPath(_outer(), Paint()..color = flame);
    canvas.drawPath(_inner(), Paint()..color = ember);
  }

  @override
  bool shouldRepaint(_FlamePainter old) =>
      old.flame != flame || old.ember != ember;
}
