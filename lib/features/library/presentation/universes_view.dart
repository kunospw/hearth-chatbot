import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/refresh.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/hearth_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/character_avatar.dart';
import '../../../core/widgets/motion_widgets.dart';
import '../../../core/widgets/states.dart';
import '../../../core/widgets/toast.dart';
import '../../characters/data/character_repository.dart';
import '../../characters/domain/character.dart';
import '../data/library_repository.dart';
import '../domain/library_models.dart';
import 'library_sheets.dart';

/// "Each universe keeps its own lore and timeline" card used on the Library and
/// Universe screens.
class TimelineNote extends StatelessWidget {
  const TimelineNote({super.key, this.leadIn});

  /// Bold first words ("Separate timeline.").
  final String? leadIn;

  @override
  Widget build(BuildContext context) {
    final c = context.hc;
    final t = context.ht;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Space.md + 2),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(Radii.card - 2),
        border: Border.all(color: c.outline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_outline, color: c.primaryInk),
          const SizedBox(width: Space.md),
          Expanded(
            child: leadIn == null
                ? Text(
                    'Each universe keeps its own lore and timeline. '
                    'What happens in one world never leaks into another.',
                    style: t.body.copyWith(color: c.textMuted),
                  )
                : Text.rich(
                    TextSpan(
                      style: t.body.copyWith(color: c.textMuted),
                      children: [
                        TextSpan(
                          text: '$leadIn ',
                          style: TextStyle(
                            color: c.text,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const TextSpan(
                          text:
                              'Lore, memories and events from this world stay here — '
                              'characters elsewhere won’t know about them.',
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

String _plural(int n, String one, String many) => '$n ${n == 1 ? one : many}';

/// The Library's Universes tab.
class UniversesView extends ConsumerWidget {
  const UniversesView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final universes = ref.watch(universesProvider);
    final chars =
        ref.watch(charactersProvider).valueOrNull ?? const <Character>[];
    final mems = ref.watch(memoriesProvider).valueOrNull ?? const <Memory>[];

    return universes.when(
      loading: () => const SkeletonRows(count: 3),
      error: (_, _) =>
          OfflineState(onRetry: () => ref.invalidate(universesProvider)),
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
            const TimelineNote(),
            const SizedBox(height: Space.md + 2),
            for (var i = 0; i < list.length; i++) ...[
              EntranceFade(
                index: i,
                child: _UniverseCard(
                  universe: list[i],
                  residents: [
                    for (final c in chars)
                      if (c.universeId == list[i].id) c,
                  ],
                  memoryCount: mems
                      .where((m) => m.universeId == list[i].id)
                      .length,
                  onTap: () => context.push(Routes.universe(list[i].id)),
                ),
              ),
              const SizedBox(height: Space.md + 2),
            ],
            OutlinedButton.icon(
              onPressed: () async {
                final r = await showUniverseSheet(context);
                if (r == null || !context.mounted) return;
                final u = await ref
                    .read(universesProvider.notifier)
                    .create(name: r.name, description: r.description);
                if (context.mounted) {
                  showToast(context, '${u.name} created');
                  context.push(Routes.universe(u.id));
                }
              },
              icon: const Icon(Icons.add),
              label: const Text('Create a universe'),
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

class _UniverseCard extends StatelessWidget {
  const _UniverseCard({
    required this.universe,
    required this.residents,
    required this.memoryCount,
    required this.onTap,
  });

  final Universe universe;
  final List<Character> residents;
  final int memoryCount;
  final VoidCallback onTap;

  static const double _face = 30;

  @override
  Widget build(BuildContext context) {
    final c = context.hc;
    final t = context.ht;
    return PressScale(
      child: Semantics(
        button: true,
        label: '${universe.name}. ${universe.era}. ${universe.description}',
        excludeSemantics: true,
        onTap: onTap,
        child: Material(
          color: c.surface,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.card + 2),
            side: BorderSide(color: c.outline),
          ),
          child: InkWell(
            onTap: onTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  color: universe.tile,
                  padding: const EdgeInsets.fromLTRB(
                    Space.lg,
                    Space.xl + Space.sm,
                    Space.lg,
                    Space.md,
                  ),
                  child: Text(
                    universe.era.toUpperCase(),
                    style: t.overline.copyWith(color: c.onScrim),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Space.lg,
                    Space.md + 2,
                    Space.lg,
                    Space.lg,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        universe.name,
                        style: t.title.copyWith(fontSize: 21),
                      ),
                      const SizedBox(height: Space.sm - 2),
                      Text(
                        universe.description,
                        style: t.body.copyWith(color: c.textMuted),
                      ),
                      const SizedBox(height: Space.md),
                      Row(
                        children: [
                          if (residents.isNotEmpty)
                            SizedBox(
                              width:
                                  _face + (residents.length - 1) * (_face - 8),
                              height: _face,
                              child: Stack(
                                children: [
                                  for (var i = 0; i < residents.length; i++)
                                    Positioned(
                                      left: i * (_face - 8),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: c.surface,
                                            width: Sizes.stroke,
                                          ),
                                        ),
                                        child: CharacterAvatar.of(
                                          residents[i],
                                          size: _face - Sizes.stroke * 2,
                                          shape: AvatarShape.circle,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          if (residents.isNotEmpty)
                            const SizedBox(width: Space.md),
                          Expanded(
                            child: Text(
                              '${_plural(residents.length, 'character', 'characters')} · '
                              '${_plural(memoryCount, 'memory', 'memories')}',
                              style: t.caption,
                            ),
                          ),
                        ],
                      ),
                    ],
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
