import 'package:flutter/material.dart';

import '../theme/hearth_theme.dart';
import '../theme/tokens.dart';
import 'tap_card.dart';

/// One conversation row: avatar, title, "character · time", one-line preview
/// and an optional separate ⋯ button (48dp). The row itself is one tap target.
class ChatTile extends StatelessWidget {
  const ChatTile({
    super.key,
    required this.avatar,
    required this.title,
    required this.subtitle,
    required this.preview,
    required this.onTap,
    this.pinned = false,
    this.onMore,
    this.moreTooltip,
    this.moreIcon = Icons.more_horiz,
    this.index = 0,
    this.selected = false,
  });

  final bool selected;
  final Widget avatar;
  final String title;

  /// "Vesper · 2m ago"
  final String subtitle;
  final String preview;
  final bool pinned;
  final VoidCallback onTap;

  /// Shows the ⋯ button when set.
  final VoidCallback? onMore;
  final String? moreTooltip;
  final IconData moreIcon;
  final int index;

  @override
  Widget build(BuildContext context) {
    final c = context.hc;
    return Semantics(
      container: true,
      child: TapCard(
        index: index,
        selected: selected,
        onTap: onTap,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            avatar,
            const SizedBox(width: Space.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.ht.label,
                        ),
                      ),
                      if (pinned)
                        Padding(
                          padding: const EdgeInsets.only(left: Space.xs),
                          child: Icon(
                            Icons.push_pin,
                            size: Space.lg,
                            color: c.pin,
                            semanticLabel: 'Pinned',
                          ),
                        ),
                    ],
                  ),
                  Text(subtitle, style: context.ht.caption),
                  const SizedBox(height: Space.xs),
                  Text(
                    preview,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.ht.body.copyWith(color: c.textMuted),
                  ),
                ],
              ),
            ),
            if (onMore != null)
              IconButton(
                tooltip: moreTooltip ?? 'More options for $title',
                icon: Icon(moreIcon),
                onPressed: onMore,
              ),
          ],
        ),
      ),
    );
  }
}

/// The large "Continue chatting" card. One tap resumes the conversation.
class ContinueCard extends StatelessWidget {
  const ContinueCard({
    super.key,
    required this.avatar,
    required this.title,
    required this.subtitle,
    required this.preview,
    required this.onTap,
    this.onMore,
    this.index = 0,
  });

  final Widget avatar;
  final String title;
  final String subtitle;
  final String preview;
  final VoidCallback onTap;

  /// Shows a ⋯ button (48dp) when set.
  final VoidCallback? onMore;
  final int index;

  @override
  Widget build(BuildContext context) {
    final c = context.hc;
    return Semantics(
      button: true,
      label: 'Continue $title. $subtitle. $preview',
      excludeSemantics: true,
      onTap: onTap,
      child: TapCard(
        index: index,
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                avatar,
                const SizedBox(width: Space.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: context.ht.title,
                      ),
                      Text(subtitle, style: context.ht.caption),
                    ],
                  ),
                ),
                if (onMore != null)
                  IconButton(
                    tooltip: 'More options for this chat',
                    constraints: const BoxConstraints(
                      minWidth: Hit.primary,
                      minHeight: Hit.primary,
                    ),
                    icon: const Icon(Icons.more_horiz),
                    onPressed: onMore,
                  ),
              ],
            ),
            const SizedBox(height: Space.md),
            Text(
              preview,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: context.ht.body.copyWith(color: c.textMuted),
            ),
            const SizedBox(height: Space.md),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Continue',
                  style: context.ht.label.copyWith(color: c.primaryInk),
                ),
                const SizedBox(width: Space.xs),
                Icon(
                  Icons.arrow_forward,
                  size: Space.xl - Space.xs,
                  color: c.primaryInk,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
