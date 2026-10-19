import 'package:flutter/material.dart';

import '../theme/hearth_theme.dart';
import '../theme/tokens.dart';

/// "‹ 2 of 3 ›" · Rewrite · Copy · Edit. Labelled, 44dp tall.
/// Always shown on the latest AI reply; older messages open these from ⋯.
/// The alt navigator only appears when there is more than one version.
class MessageActions extends StatelessWidget {
  const MessageActions({
    super.key,
    this.altIndex = 0,
    this.altCount = 1,
    this.onPrevAlt,
    this.onNextAlt,
    this.onRewrite,
    this.onCopy,
    this.onEdit,
    this.rewriteLabel = 'Rewrite',
  });

  /// Zero-based index of the visible version.
  final int altIndex;
  final int altCount;
  final VoidCallback? onPrevAlt;
  final VoidCallback? onNextAlt;
  final VoidCallback? onRewrite;
  final VoidCallback? onCopy;
  final VoidCallback? onEdit;

  /// "Rewrite passage" in Story mode.
  final String rewriteLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.hc;
    final multiple = altCount > 1;
    final atStart = altIndex <= 0;
    final atEnd = altIndex >= altCount - 1;

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: Space.xs,
      runSpacing: Space.xs,
      children: [
        if (multiple)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _icon(
                Icons.chevron_left,
                'Previous version',
                atStart ? null : onPrevAlt,
              ),
              Semantics(
                liveRegion: true,
                child: Text(
                  '${altIndex + 1} of $altCount',
                  style: context.ht.caption.copyWith(color: c.textMuted),
                ),
              ),
              _icon(
                Icons.chevron_right,
                'Next version',
                atEnd ? null : onNextAlt,
              ),
            ],
          ),
        if (onRewrite != null)
          _action(context, Icons.refresh, rewriteLabel, onRewrite!),
        if (onCopy != null)
          _action(context, Icons.copy_outlined, 'Copy', onCopy!),
        if (onEdit != null)
          _action(context, Icons.edit_outlined, 'Edit', onEdit!),
      ],
    );
  }

  Widget _icon(IconData icon, String tooltip, VoidCallback? onPressed) {
    return IconButton(
      tooltip: tooltip,
      icon: Icon(icon),
      onPressed: onPressed,
      style: IconButton.styleFrom(minimumSize: const Size.square(Hit.inline)),
    );
  }

  Widget _action(
    BuildContext context,
    IconData icon,
    String label,
    VoidCallback onTap,
  ) {
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: Space.xl - Space.xs),
      label: Text(
        label,
        style: context.ht.body.copyWith(fontWeight: FontWeight.w600),
      ),
      style: TextButton.styleFrom(
        foregroundColor: context.hc.textMuted,
        minimumSize: const Size(Hit.inline, Hit.inline),
        padding: const EdgeInsets.symmetric(horizontal: Space.md),
      ),
    );
  }
}
