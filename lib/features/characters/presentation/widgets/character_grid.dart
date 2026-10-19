import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';

/// Lays widgets out in 2 columns (3 from 600dp) as equal-height rows. Rows
/// size to their tallest card, so nothing overflows at large text sizes
/// (a fixed-aspect SliverGrid would).
class CharacterGrid extends StatelessWidget {
  const CharacterGrid({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final cols = MediaQuery.sizeOf(context).width >= Breakpoints.medium ? 3 : 2;
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i += cols) {
      final slice = children.sublist(i, (i + cols).clamp(0, children.length));
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var j = 0; j < cols; j++) ...[
                if (j > 0) const SizedBox(width: Space.md),
                Expanded(
                  child: j < slice.length ? slice[j] : const SizedBox.shrink(),
                ),
              ],
            ],
          ),
        ),
      );
      if (i + cols < children.length) {
        rows.add(const SizedBox(height: Space.md));
      }
    }
    return Column(children: rows);
  }
}
