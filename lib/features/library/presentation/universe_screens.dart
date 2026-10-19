import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';
import '../../../core/theme/hearth_theme.dart';
import '../../../core/widgets/overline.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/character_avatar.dart';
import '../../../core/widgets/states.dart';
import '../../../core/widgets/tap_card.dart';
import '../../../core/widgets/toast.dart';
import '../../characters/data/character_repository.dart';
import '../../characters/domain/character.dart';
import '../data/library_repository.dart';
import '../domain/library_models.dart';
import 'library_sheets.dart';
import 'memories_view.dart';
import 'universes_view.dart';

void _back(BuildContext context) =>
    context.canPop() ? context.pop() : context.go(Routes.characters);

/// One universe: hero, description, separate-timeline note, its characters, and
/// a link to its memories. Edit opens the universe sheet.
class UniverseDetailScreen extends ConsumerWidget {
  const UniverseDetailScreen({super.key, required this.universeId});

  final String universeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final universes = ref.watch(universesProvider);
    return universes.when(
      loading: () =>
          Scaffold(appBar: AppBar(), body: const SkeletonRows(count: 3)),
      error: (_, _) =>
          Scaffold(appBar: AppBar(), body: const SizedBox.shrink()),
      data: (list) {
        Universe? uni;
        for (final u in list) {
          if (u.id == universeId) uni = u;
        }
        if (uni == null) {
          return Scaffold(
            appBar: AppBar(),
            body: EmptyState(
              title: 'We can’t find this universe',
              primaryLabel: 'Back to the library',
              onPrimary: () => context.go(Routes.library()),
            ),
          );
        }
        return _Body(universe: uni);
      },
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.universe});

  final Universe universe;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.hc;
    final t = context.ht;
    final chars = [
      for (final ch
          in ref.watch(charactersProvider).valueOrNull ?? const <Character>[])
        if (ch.universeId == universe.id) ch,
    ];
    final mems = [
      for (final m
          in ref.watch(memoriesProvider).valueOrNull ?? const <Memory>[])
        if (m.universeId == universe.id) m,
    ];

    Widget overlayButton({required Widget child}) =>
        Material(color: c.scrim, shape: const StadiumBorder(), child: child);

    return Scaffold(
      body: Stack(
        children: [
          ListView(
            padding: EdgeInsets.zero,
            children: [
              Container(
                color: universe.tile,
                padding: const EdgeInsets.fromLTRB(
                  Space.sm,
                  0,
                  Space.gutter,
                  Space.lg + 2,
                ),
                constraints: const BoxConstraints(minHeight: 200),
                child: SafeArea(
                  bottom: false,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: Hit.primary + Space.sm),
                      const SizedBox(height: Space.xxl + Space.xl),
                      Padding(
                        padding: const EdgeInsets.only(left: Space.sm),
                        child: Text(
                          universe.era.toUpperCase(),
                          style: t.overline.copyWith(color: c.onScrim),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(Space.gutter),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(universe.name, style: t.display),
                    const SizedBox(height: Space.sm),
                    Text(
                      universe.description,
                      style: t.body.copyWith(fontSize: 16, color: c.textMuted),
                    ),
                    const SizedBox(height: Space.lg + 2),
                    const TimelineNote(leadIn: 'Separate timeline.'),
                    const SizedBox(height: Space.lg + 2),
                    Overline('Characters here'),
                    const SizedBox(height: Space.sm),
                    for (var i = 0; i < chars.length; i++) ...[
                      TapCard(
                        index: i,
                        onTap: () =>
                            context.push(Routes.character(chars[i].id)),
                        child: Row(
                          children: [
                            CharacterAvatar.of(
                              chars[i],
                              size: Sizes.avatar - 4,
                            ),
                            const SizedBox(width: Space.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    chars[i].name,
                                    style: t.label.copyWith(fontSize: 15),
                                  ),
                                  Text(
                                    chars[i].short,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: t.caption.copyWith(
                                      color: c.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.chevron_right, color: c.textSubtle),
                          ],
                        ),
                      ),
                      const SizedBox(height: Space.sm),
                    ],
                    if (chars.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(Space.md + 2),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(Radii.button),
                          border: Border.all(color: c.outline),
                        ),
                        child: Text(
                          'No one lives here yet. Give a character this universe in their “More details”.',
                          style: t.body.copyWith(color: c.textSubtle),
                        ),
                      ),
                    const SizedBox(height: Space.md),
                    TapCard(
                      onTap: () =>
                          context.push(Routes.universeMemories(universe.id)),
                      child: Row(
                        children: [
                          Icon(Icons.push_pin_outlined, color: c.pin),
                          const SizedBox(width: Space.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Memories & lore',
                                  style: t.label.copyWith(fontSize: 15),
                                ),
                                Text(
                                  '${mems.length} saved · ${mems.where((m) => m.pinned).length} pinned',
                                  style: t.caption.copyWith(color: c.textMuted),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right, color: c.textSubtle),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Pinned: Back and Edit stay reachable however far you scroll.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  Space.sm,
                  Space.sm,
                  Space.gutter,
                  0,
                ),
                child: Row(
                  children: [
                    overlayButton(
                      child: IconButton(
                        tooltip: 'Back',
                        icon: Icon(Icons.arrow_back, color: c.onScrim),
                        onPressed: () => _back(context),
                      ),
                    ),
                    const Spacer(),
                    overlayButton(
                      child: TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: c.onScrim,
                          minimumSize: const Size(Hit.primary, Hit.inline),
                          padding: const EdgeInsets.symmetric(
                            horizontal: Space.lg + 2,
                          ),
                        ),
                        onPressed: () async {
                          final r = await showUniverseSheet(
                            context,
                            universe: universe,
                          );
                          if (r == null || !context.mounted) return;
                          await ref
                              .read(universesProvider.notifier)
                              .edit(
                                universe.id,
                                name: r.name,
                                description: r.description,
                              );
                          if (context.mounted) {
                            showToast(context, 'Universe saved');
                          }
                        },
                        child: const Text('Edit'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The memories of one universe as a full screen (from a chat's ⋯ menu or the
/// universe page).
class UniverseMemoriesScreen extends ConsumerWidget {
  const UniverseMemoriesScreen({super.key, required this.universeId});

  final String universeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.ht;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.xs,
                Space.sm,
                Space.gutter,
                0,
              ),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Back',
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => _back(context),
                  ),
                  Expanded(
                    child: Text(
                      'Memories',
                      style: t.display.copyWith(fontSize: 26),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: MemoriesView(universeId: universeId)),
          ],
        ),
      ),
    );
  }
}
