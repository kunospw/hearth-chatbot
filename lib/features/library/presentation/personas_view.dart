import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/refresh.dart';
import '../../../core/theme/hearth_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/controls.dart';
import '../../../core/widgets/states.dart';
import '../../../core/widgets/toast.dart';
import '../data/library_repository.dart';
import 'library_sheets.dart';

/// The Library's Personas tab: who you are in the story, as a radio list.
class PersonasView extends ConsumerWidget {
  const PersonasView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.hc;
    final personas = ref.watch(personasProvider);
    final selected = ref.watch(activePersonaIdProvider);

    return personas.when(
      loading: () => const SkeletonRows(count: 2),
      error: (_, _) =>
          OfflineState(onRetry: () => ref.invalidate(personasProvider)),
      data: (list) => PullToRefresh(
        child: ListView(
          physics: refreshablePhysics,
          padding: const EdgeInsets.fromLTRB(
            Space.gutter,
            Space.lg + 2,
            Space.gutter,
            Space.xxl,
          ),
          children: [
            Text(
              'A persona is who you are in the story. Characters will treat you as this person.',
              style: context.ht.body.copyWith(color: c.textMuted),
            ),
            const SizedBox(height: Space.md),
            for (final p in list) ...[
              RadioCard(
                title: p.name,
                subtitle: p.description,
                selected: p.id == selected,
                leading: Container(
                  width: Space.xxl + Space.md,
                  height: Space.xxl + Space.md,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: c.surfaceRaised,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    p.initial,
                    textScaler: TextScaler.noScaling,
                    style: context.ht.label.copyWith(color: c.text),
                  ),
                ),
                onTap: () {
                  ref.read(selectedPersonaIdProvider.notifier).select(p.id);
                  showToast(context, 'Now playing as ${p.name}');
                },
              ),
              const SizedBox(height: Space.sm + 2),
            ],
            const SizedBox(height: Space.xs),
            OutlinedButton.icon(
              onPressed: () async {
                final r = await showPersonaSheet(context);
                if (r == null || !context.mounted) return;
                final p = await ref
                    .read(personasProvider.notifier)
                    .add(name: r.name, description: r.description);
                if (!context.mounted) return;
                ref.read(selectedPersonaIdProvider.notifier).select(p.id);
                showToast(context, 'Now playing as ${p.name}');
              },
              icon: const Icon(Icons.add),
              label: const Text('New persona'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(Hit.primary + Space.sm),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
