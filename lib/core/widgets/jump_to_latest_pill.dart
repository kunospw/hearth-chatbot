import 'package:flutter/material.dart';

import '../theme/hearth_theme.dart';
import '../theme/tokens.dart';
import 'motion_widgets.dart';

/// "New reply below" pill shown while content arrives below the viewport and
/// the user is reading earlier messages. Place it in a Stack above the
/// composer, centred. Floating, so it carries a shadow.
///
/// When hidden it is removed from the tree (after a short fade), so it can't
/// be tapped or announced by a screen reader.
class JumpToLatestPill extends StatelessWidget {
  const JumpToLatestPill({
    super.key,
    required this.visible,
    required this.onTap,
    this.label = 'New reply below',
  });

  final bool visible;
  final VoidCallback onTap;
  final String label;

  @override
  Widget build(BuildContext context) {
    final d = reduceMotion(context) ? Duration.zero : Motion.sheet;
    return AnimatedSwitcher(
      duration: d,
      reverseDuration: reduceMotion(context) ? Duration.zero : Motion.press,
      switchInCurve: Motion.emphasizedDecelerate,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, 0.6),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: visible
          ? _Pill(key: const ValueKey('pill'), label: label, onTap: onTap)
          : const SizedBox.shrink(key: ValueKey('none')),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.hc;
    return Material(
      color: c.text,
      elevation: Space.sm,
      shadowColor: c.scrim,
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: Hit.inline),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.lg),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.arrow_downward_rounded,
                  size: Space.lg + Space.xs,
                  color: c.onInverse,
                ),
                const SizedBox(width: Space.sm),
                Flexible(
                  child: Text(
                    label,
                    style: context.ht.body.copyWith(
                      color: c.onInverse,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
