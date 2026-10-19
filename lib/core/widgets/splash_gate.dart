import 'package:flutter/material.dart';

import '../theme/hearth_theme.dart';
import '../theme/tokens.dart';
import 'hearth_logo.dart';
import 'motion_widgets.dart';

/// Brief branded intro on cold start: the flame settles in, then the whole
/// overlay fades away to reveal the app. Skipped when animations are removed.
class SplashGate extends StatefulWidget {
  const SplashGate({super.key, required this.child});

  final Widget child;

  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate>
    with SingleTickerProviderStateMixin {
  static const _total = Duration(milliseconds: 1200);
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: _total,
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (reduceMotion(context)) return widget.child;
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            if (_c.isCompleted) return const SizedBox.shrink();
            final intro = Motion.emphasizedDecelerate.transform(
              const Interval(0, 0.45).transform(_c.value),
            );
            final out = Curves.easeIn.transform(
              const Interval(0.72, 1).transform(_c.value),
            );
            return IgnorePointer(
              child: Opacity(
                opacity: 1 - out,
                child: ColoredBox(
                  color: context.hc.bg,
                  child: Center(
                    child: Opacity(
                      opacity: intro,
                      child: Transform.scale(
                        scale: 0.8 + 0.2 * intro,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const HearthLogo(size: Sizes.logoSplash),
                            const SizedBox(height: Space.lg),
                            Text(
                              'Hearth',
                              style: context.ht.display.copyWith(
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
