import 'package:flutter/material.dart';

import '../theme/hearth_theme.dart';
import '../theme/tokens.dart';

enum NoticeTone { error, info }

/// Error / limit card that sits in the message list. Has a primary and an
/// optional secondary action; the user's message is always kept.
class InlineNotice extends StatelessWidget {
  const InlineNotice({
    super.key,
    required this.title,
    required this.message,
    required this.primaryLabel,
    required this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
    this.icon = Icons.error_outline,
    this.tone = NoticeTone.error,
  });

  final String title;
  final String message;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final IconData icon;
  final NoticeTone tone;

  @override
  Widget build(BuildContext context) {
    final c = context.hc;
    final accent = tone == NoticeTone.error ? c.danger : c.primaryInk;
    return Semantics(
      container: true,
      liveRegion: true,
      label: '$title. $message',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(Space.lg),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(Radii.card),
          border: Border.all(color: c.outline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: accent),
                const SizedBox(width: Space.md),
                Expanded(child: Text(title, style: context.ht.label)),
              ],
            ),
            const SizedBox(height: Space.sm),
            Text(message, style: context.ht.body.copyWith(color: c.textMuted)),
            const SizedBox(height: Space.lg),
            Wrap(
              spacing: Space.sm,
              runSpacing: Space.sm,
              children: [
                FilledButton(onPressed: onPrimary, child: Text(primaryLabel)),
                if (secondaryLabel != null && onSecondary != null)
                  OutlinedButton(
                    onPressed: onSecondary,
                    child: Text(secondaryLabel!),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
