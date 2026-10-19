import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// True when the user asked to remove animations (SPEC §3).
bool reduceMotion(BuildContext context) =>
    MediaQuery.disableAnimationsOf(context);

/// Fades and rises a child into place once, optionally after a stagger delay.
/// Use [index] in lists so items cascade; the delay is capped so long lists
/// don't feel slow.
class EntranceFade extends StatelessWidget {
  const EntranceFade({super.key, required this.child, this.index = 0});

  final Widget child;
  final int index;

  static const _stagger = Duration(milliseconds: 70);
  static const _maxSteps = 6;
  static const double _rise = Space.lg;

  @override
  Widget build(BuildContext context) {
    if (reduceMotion(context)) return child;
    final delay = _stagger * (index > _maxSteps ? _maxSteps : index);
    final total = Motion.enter + delay;
    final lead = delay.inMilliseconds / total.inMilliseconds;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: total,
      curve: Interval(lead, 1, curve: Motion.soft),
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, (1 - t) * _rise),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

/// Springs a child slightly down while it is pressed. Wrap the tappable
/// surface (the InkWell keeps its own ripple and semantics).
class PressScale extends StatefulWidget {
  const PressScale({super.key, required this.child, this.scale = 0.97});

  final Widget child;
  final double scale;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v && mounted) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _down && !reduceMotion(context) ? widget.scale : 1,
        duration: Motion.press,
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
