import 'package:flutter/material.dart';

import '../theme/hearth_theme.dart';
import '../theme/tokens.dart';
import 'motion_widgets.dart';

// ── Skeletons ────────────────────────────────────────────────────────────

class _SkeletonTone extends InheritedWidget {
  const _SkeletonTone({required this.color, required super.child});

  final Color color;

  static Color of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_SkeletonTone>()?.color ??
      context.hc.surface;

  @override
  bool updateShouldNotify(_SkeletonTone old) => old.color != color;
}

/// Wraps skeleton boxes so they pulse together between surface and
/// surfaceRaised. Static when animations are removed.
class Skeleton extends StatefulWidget {
  const Skeleton({super.key, required this.child, this.label = 'Loading'});

  final Widget child;
  final String label;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reduceMotion(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.hc;
    return Semantics(
      label: widget.label,
      liveRegion: true,
      child: ExcludeSemantics(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, child) => _SkeletonTone(
            color: Color.lerp(
              c.surface,
              c.surfaceRaised,
              Curves.easeInOut.transform(_c.value),
            )!,
            child: child!,
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    this.width,
    required this.height,
    this.radius = Radii.field,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: _SkeletonTone.of(context),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// Home's loading state: greeting, search, a large resume card, two rows and
/// a grid of character cards.
class HomeSkeleton extends StatelessWidget {
  const HomeSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Skeleton(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(Space.gutter),
        children: [
          const SkeletonBox(width: 180, height: 28),
          const SizedBox(height: Space.lg),
          const SkeletonBox(height: Hit.primary),
          const SizedBox(height: Space.xl),
          const SkeletonBox(height: 132, radius: Radii.card),
          const SizedBox(height: Space.md),
          const SkeletonBox(height: 64, radius: Radii.card),
          const SizedBox(height: Space.sm),
          const SkeletonBox(height: 64, radius: Radii.card),
          const SizedBox(height: Space.xl),
          Row(
            children: const [
              Expanded(child: SkeletonBox(height: 210, radius: Radii.card)),
              SizedBox(width: Space.md),
              Expanded(child: SkeletonBox(height: 210, radius: Radii.card)),
            ],
          ),
        ],
      ),
    );
  }
}

/// Loading rows for list screens such as Chats and Memories.
class SkeletonRows extends StatelessWidget {
  const SkeletonRows({super.key, this.count = 5});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Skeleton(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(Space.gutter),
        children: [
          for (var i = 0; i < count; i++) ...[
            const Row(
              children: [
                SkeletonBox(width: Hit.primary, height: Hit.primary),
                SizedBox(width: Space.md),
                Expanded(child: SkeletonBox(height: Hit.primary)),
              ],
            ),
            const SizedBox(height: Space.md),
          ],
        ],
      ),
    );
  }
}

// ── Empty / first-run / offline ──────────────────────────────────────────

/// Centred message with up to two actions. Scrolls so it survives large text
/// and short screens.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    this.message,
    this.icon,
    this.primaryLabel,
    this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
  });

  final String title;
  final String? message;
  final Widget? icon;
  final String? primaryLabel;
  final VoidCallback? onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) => SingleChildScrollView(
        padding: const EdgeInsets.all(Space.gutter),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: box.maxHeight - Space.gutter * 2,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: Reading.storyMaxWidth / 1.5,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    icon!,
                    const SizedBox(height: Space.lg),
                  ],
                  Text(
                    title,
                    style: context.ht.display.copyWith(fontSize: 26),
                    textAlign: TextAlign.center,
                  ),
                  if (message != null) ...[
                    const SizedBox(height: Space.sm),
                    Text(
                      message!,
                      style: context.ht.body.copyWith(
                        color: context.hc.textMuted,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  if (primaryLabel != null) ...[
                    const SizedBox(height: Space.xl),
                    FilledButton(
                      onPressed: onPrimary,
                      child: Text(primaryLabel!),
                    ),
                  ],
                  if (secondaryLabel != null) ...[
                    const SizedBox(height: Space.sm),
                    OutlinedButton(
                      onPressed: onSecondary,
                      child: Text(secondaryLabel!),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Home's empty state: "Your first story starts here".
class FirstRunState extends StatelessWidget {
  const FirstRunState({
    super.key,
    required this.onMeetSamples,
    required this.onCreate,
    this.icon,
  });

  final VoidCallback onMeetSamples;
  final VoidCallback onCreate;
  final Widget? icon;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: icon,
      title: 'Your first story starts here',
      message: 'Meet a character, or make one of your own.',
      primaryLabel: 'Meet the sample characters',
      onPrimary: onMeetSamples,
      secondaryLabel: 'Create my own',
      onSecondary: onCreate,
    );
  }
}

/// Home's error state: "Can't reach Hearth right now".
class OfflineState extends StatelessWidget {
  const OfflineState({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icon(
        Icons.cloud_off_outlined,
        size: Space.xxl + Space.lg,
        color: context.hc.textSubtle,
      ),
      title: 'Can’t reach Hearth right now',
      message: 'Check your connection. Your stories are safe.',
      primaryLabel: 'Try again',
      onPrimary: onRetry,
    );
  }
}

/// Slim banner for list screens that are showing saved data while offline.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({
    super.key,
    this.message = 'You’re offline. Showing what’s saved.',
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    final c = context.hc;
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: Space.gutter,
          vertical: Space.md,
        ),
        color: c.surfaceRaised,
        child: Row(
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: Space.xl - Space.xs,
              color: c.textMuted,
            ),
            const SizedBox(width: Space.md),
            Expanded(
              child: Text(
                message,
                style: context.ht.caption.copyWith(color: c.textMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
