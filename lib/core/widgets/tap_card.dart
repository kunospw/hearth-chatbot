import 'package:flutter/material.dart';

import '../theme/hearth_theme.dart';
import '../theme/tokens.dart';
import 'motion_widgets.dart';

/// A tappable surface card with an entrance animation and press feedback.
class TapCard extends StatelessWidget {
  const TapCard({
    super.key,
    required this.onTap,
    required this.child,
    this.index = 0,
    this.selected = false,
  });

  final VoidCallback onTap;
  final Widget child;

  /// Position in a list, used to stagger the entrance.
  final int index;

  /// Highlights the card (the open chat in the wide Chats layout).
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return EntranceFade(
      index: index,
      child: PressScale(
        child: Material(
          color: selected ? context.hc.primarySoft : context.hc.surface,
          borderRadius: BorderRadius.circular(Radii.card),
          child: InkWell(
            borderRadius: BorderRadius.circular(Radii.card),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(Space.lg),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
