import 'package:flutter/material.dart';

import '../theme/hearth_theme.dart';

/// A section label in the overline style: 13dp, weight 600, +6% spacing,
/// **uppercase** (SPEC §2). Screen readers still hear the original wording.
class Overline extends StatelessWidget {
  const Overline(this.text, {super.key, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final style = context.ht.overline;
    return Semantics(
      header: true,
      label: text,
      excludeSemantics: true,
      child: Text(
        text.toUpperCase(),
        style: color == null ? style : style.copyWith(color: color),
      ),
    );
  }
}
