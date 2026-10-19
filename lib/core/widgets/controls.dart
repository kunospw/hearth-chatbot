import 'package:flutter/material.dart';

import '../theme/hearth_theme.dart';
import '../theme/tokens.dart';

/// Segmented control. Selected = light pill (#EEE7E1 with dark text).
/// Segments are at least 44dp tall and share the width equally.
class HearthSegmented<T> extends StatelessWidget {
  const HearthSegmented({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.semanticLabel,
  });

  /// Value → label, in display order.
  final Map<T, String> options;
  final T value;
  final ValueChanged<T> onChanged;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.hc;
    return Semantics(
      container: true,
      label: semanticLabel,
      child: Container(
        padding: const EdgeInsets.all(Space.xs),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(Radii.button + Space.xs),
          border: Border.all(color: c.outline),
        ),
        child: Row(
          children: [
            for (final e in options.entries)
              Expanded(
                // Wider segments for longer labels, so "True black" stays on one line.
                flex: e.value.length < 6 ? 6 : e.value.length,
                child: Semantics(
                  button: true,
                  selected: e.key == value,
                  inMutuallyExclusiveGroup: true,
                  label: e.value,
                  excludeSemantics: true,
                  onTap: () => onChanged(e.key),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onChanged(e.key),
                    child: AnimatedContainer(
                      duration: Motion.press,
                      curve: Curves.easeOut,
                      constraints: const BoxConstraints(minHeight: Hit.inline),
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(
                        horizontal: Space.sm,
                        vertical: Space.sm,
                      ),
                      decoration: BoxDecoration(
                        color: e.key == value ? c.text : Colors.transparent,
                        borderRadius: BorderRadius.circular(Radii.button),
                      ),
                      child: AnimatedDefaultTextStyle(
                        duration: Motion.press,
                        style: context.ht.label.copyWith(
                          color: e.key == value ? c.onInverse : c.textMuted,
                        ),
                        textAlign: TextAlign.center,
                        child: Text(e.value),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Filter chip. Selected = soft-burgundy fill with rose-ink text. The visual
/// chip is compact but its tap target is at least 44dp tall.
class HearthChip extends StatelessWidget {
  const HearthChip({
    super.key,
    required this.label,
    required this.onTap,
    this.selected = false,
    this.icon,
  });

  final String label;
  final VoidCallback onTap;
  final bool selected;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = context.hc;
    final fg = selected ? c.primaryInk : c.textMuted;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: Hit.inline),
        child: Center(
          widthFactor: 1,
          heightFactor: 1,
          child: Material(
            color: selected ? c.primarySoft : c.surfaceRaised,
            shape: StadiumBorder(
              side: BorderSide(
                color: selected ? c.primaryInk : Colors.transparent,
              ),
            ),
            child: InkWell(
              customBorder: const StadiumBorder(),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: Space.lg,
                  vertical: Space.sm,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: Space.lg + Space.xs, color: fg),
                      const SizedBox(width: Space.xs),
                    ],
                    Flexible(
                      child: Text(
                        label,
                        style: context.ht.body.copyWith(
                          color: fg,
                          fontWeight: FontWeight.w600,
                        ),
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
  }
}

/// Title + optional description with a trailing switch. The whole row toggles.
class SwitchRow extends StatelessWidget {
  const SwitchRow({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: InkWell(
        onTap: () => onChanged(!value),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: Hit.primary + Space.sm),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: Space.sm),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: context.ht.body),
                      if (subtitle != null)
                        Text(subtitle!, style: context.ht.caption),
                    ],
                  ),
                ),
                const SizedBox(width: Space.md),
                Switch(value: value, onChanged: onChanged),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Radio row: a ring that fills when selected, a title, optional description
/// and an optional trailing status (for example a model's availability).
class RadioRow extends StatelessWidget {
  const RadioRow({
    super.key,
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.status,
    this.statusColor,
    this.enabled = true,
  });

  final String title;
  final String? subtitle;

  /// A line below the subtitle, e.g. "Available · 2 of 30 free replies left today".
  final String? status;
  final Color? statusColor;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.hc;
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      enabled: enabled,
      button: true,
      onTap: enabled ? onTap : null,
      excludeSemantics: true,
      label: [title, ?subtitle, ?status].join('. '),
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: Hit.primary + Space.sm),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: Space.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Ring(selected: selected, enabled: enabled),
                const SizedBox(width: Space.lg),
                Expanded(
                  child: Opacity(
                    opacity: enabled ? 1 : 0.6,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: context.ht.label),
                        if (subtitle != null)
                          Text(
                            subtitle!,
                            style: context.ht.body.copyWith(color: c.textMuted),
                          ),
                        if (status != null)
                          Padding(
                            padding: const EdgeInsets.only(top: Space.xs),
                            child: Text(
                              status!,
                              style: context.ht.caption.copyWith(
                                color: statusColor ?? c.textSubtle,
                              ),
                            ),
                          ),
                      ],
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

class _Ring extends StatelessWidget {
  const _Ring({required this.selected, required this.enabled});

  final bool selected;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final c = context.hc;
    final ring = selected ? c.primaryInk : c.outline;
    return AnimatedContainer(
      duration: Motion.press,
      width: Space.xl,
      height: Space.xl,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: enabled ? ring : c.outline,
          width: Sizes.stroke,
        ),
      ),
      alignment: Alignment.center,
      child: AnimatedContainer(
        duration: Motion.press,
        width: selected ? Space.md : 0,
        height: selected ? Space.md : 0,
        decoration: BoxDecoration(shape: BoxShape.circle, color: c.primaryInk),
      ),
    );
  }
}

/// A radio choice shown as a card (personas, AI models): optional leading
/// widget, title, description, and an optional status line with a coloured
/// dot. The selected card gets a rose border; unavailable cards are dimmed
/// but keep their reason visible.
class RadioCard extends StatelessWidget {
  const RadioCard({
    super.key,
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.leading,
    this.status,
    this.statusColor,
    this.enabled = true,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final String? status;
  final Color? statusColor;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.hc;
    final dimmed = !enabled && !selected;
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      enabled: enabled,
      button: true,
      onTap: enabled ? onTap : null,
      excludeSemantics: true,
      label: [title, ?subtitle, ?status].join('. '),
      child: Opacity(
        opacity: dimmed ? 0.7 : 1,
        child: Material(
          color: c.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.card),
            side: BorderSide(
              color: selected ? c.primaryInk : c.outline,
              width: selected ? Sizes.stroke : 1,
            ),
          ),
          child: InkWell(
            customBorder: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Radii.card),
            ),
            onTap: enabled ? onTap : null,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: Hit.primary + Space.md,
              ),
              child: Padding(
                padding: const EdgeInsets.all(Space.lg - 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (leading != null) ...[
                      leading!,
                      const SizedBox(width: Space.md),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: context.ht.label),
                          if (subtitle != null)
                            Text(
                              subtitle!,
                              style: context.ht.body.copyWith(
                                color: c.textMuted,
                              ),
                            ),
                          if (status != null)
                            Padding(
                              padding: const EdgeInsets.only(top: Space.xs + 2),
                              child: Row(
                                children: [
                                  Container(
                                    width: Space.sm,
                                    height: Space.sm,
                                    decoration: BoxDecoration(
                                      color: statusColor ?? c.textSubtle,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: Space.sm - 2),
                                  Expanded(
                                    child: Text(
                                      status!,
                                      style: context.ht.caption.copyWith(
                                        color: statusColor ?? c.textSubtle,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: Space.md),
                    _Ring(selected: selected, enabled: enabled || selected),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
