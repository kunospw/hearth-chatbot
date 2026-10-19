import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/refresh.dart';
import '../../../core/theme/hearth_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/controls.dart';
import '../../../core/widgets/states.dart';
import '../../../core/widgets/toast.dart';
import '../data/library_repository.dart';
import '../domain/library_models.dart';
import 'library_sheets.dart';

/// Memories for one universe, in four groups. Pin toggles in place (items don't
/// jump), tapping a memory opens the edit sheet, and deleting offers Undo.
///
/// With [universeId] set it shows that universe; otherwise it shows a row of
/// universe chips (the Library tab).
class MemoriesView extends ConsumerStatefulWidget {
  const MemoriesView({super.key, this.universeId});

  final String? universeId;

  @override
  ConsumerState<MemoriesView> createState() => _MemoriesViewState();
}

class _MemoriesViewState extends ConsumerState<MemoriesView> {
  String? _picked;

  Future<void> _add(String universeId) async {
    final r = await showMemorySheet(context);
    if (!mounted || r is! MemorySaved) return;
    await ref
        .read(memoriesProvider.notifier)
        .add(
          universeId: universeId,
          category: r.category,
          text: r.text,
          pinned: r.pinned,
        );
    if (mounted) showToast(context, 'Memory saved');
  }

  Future<void> _edit(Memory m) async {
    final r = await showMemorySheet(context, memory: m);
    if (!mounted || r == null) return;
    final notifier = ref.read(memoriesProvider.notifier);
    switch (r) {
      case MemorySaved():
        await notifier.edit(
          m.copyWith(text: r.text, category: r.category, pinned: r.pinned),
        );
        if (mounted) showToast(context, 'Memory saved');
      case MemoryDeleted():
        final removed = await notifier.remove(m.id);
        if (!mounted || removed == null) return;
        showToast(
          context,
          'Memory deleted',
          onUndo: () => notifier.restore(removed),
        );
    }
  }

  Future<void> _togglePin(Memory m) async {
    await ref.read(memoriesProvider.notifier).togglePin(m.id);
    if (mounted) {
      showToast(context, m.pinned ? 'Unpinned' : 'Pinned — always remembered');
    }
  }

  @override
  Widget build(BuildContext context) {
    final universes = ref.watch(universesProvider);
    final memories = ref.watch(memoriesProvider);

    return universes.when(
      loading: () => const SkeletonRows(),
      error: (_, _) =>
          OfflineState(onRetry: () => ref.invalidate(universesProvider)),
      data: (unis) {
        if (unis.isEmpty) {
          return const EmptyState(
            title: 'No universes yet',
            message: 'Create a universe first, then give it memories.',
          );
        }
        final current = widget.universeId ?? _picked ?? unis.first.id;
        final uni = unis.firstWhere(
          (u) => u.id == current,
          orElse: () => unis.first,
        );
        return memories.when(
          loading: () => const SkeletonRows(),
          error: (_, _) =>
              OfflineState(onRetry: () => ref.invalidate(memoriesProvider)),
          data: (all) => _content(
            context,
            unis,
            uni,
            all.where((m) => m.universeId == uni.id).toList(),
          ),
        );
      },
    );
  }

  Widget _content(
    BuildContext context,
    List<Universe> unis,
    Universe uni,
    List<Memory> mems,
  ) {
    final c = context.hc;
    final t = context.ht;
    return PullToRefresh(
      child: ListView(
        physics: refreshablePhysics,
        padding: const EdgeInsets.only(top: Space.lg, bottom: Space.xxl),
        children: [
          if (widget.universeId == null)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
              child: Row(
                children: [
                  for (final u in unis)
                    Padding(
                      padding: const EdgeInsets.only(right: Space.sm),
                      child: HearthChip(
                        label: u.name,
                        selected: u.id == uni.id,
                        onTap: () => setState(() => _picked = u.id),
                      ),
                    ),
                ],
              ),
            ),
          if (widget.universeId == null) const SizedBox(height: Space.lg),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: Space.lg,
                vertical: Space.md + 2,
              ),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(Radii.card),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'How memories work',
                    style: t.label.copyWith(fontSize: 15),
                  ),
                  const SizedBox(height: Space.xs + 2),
                  Text.rich(
                    TextSpan(
                      style: t.body.copyWith(color: c.textMuted),
                      children: [
                        TextSpan(
                          text:
                              'Characters in ${uni.name} remember these during your chats. ',
                        ),
                        TextSpan(
                          text: 'Pinned',
                          style: TextStyle(
                            color: c.pin,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const TextSpan(
                          text: ' memories are always remembered; the rest come up when they matter.',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: Space.lg),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
            child: FilledButton.icon(
              onPressed: () => _add(uni.id),
              icon: const Icon(Icons.add),
              label: const Text('Add a memory'),
            ),
          ),
          for (final cat in MemoryCategory.values) ...[
            const SizedBox(height: Space.xl),
            _Group(
              category: cat,
              items: [
                for (final m in mems)
                  if (m.category == cat) m,
              ],
              onEdit: _edit,
              onPin: _togglePin,
            ),
          ],
        ],
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({
    required this.category,
    required this.items,
    required this.onEdit,
    required this.onPin,
  });

  final MemoryCategory category;
  final List<Memory> items;
  final ValueChanged<Memory> onEdit;
  final ValueChanged<Memory> onPin;

  @override
  Widget build(BuildContext context) {
    final c = context.hc;
    final t = context.ht;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(category.label, style: t.label),
          Text(category.hint, style: t.caption),
          const SizedBox(height: Space.sm),
          for (final m in items)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.sm),
              child: Container(
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(Radii.button),
                  border: Border.all(
                    color: m.pinned ? c.pin.withValues(alpha: 0.55) : c.outline,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Semantics(
                        button: true,
                        label: 'Edit memory: ${m.text}',
                        excludeSemantics: true,
                        onTap: () => onEdit(m),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(Radii.button),
                          onTap: () => onEdit(m),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              minHeight: Hit.primary,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                Space.md + 2,
                                Space.md,
                                Space.xs,
                                Space.md,
                              ),
                              child: Align(
                                alignment: AlignmentDirectional.centerStart,
                                child: Text(m.text, style: t.body),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: m.pinned ? 'Unpin memory' : 'Pin memory',
                      isSelected: m.pinned,
                      onPressed: () => onPin(m),
                      icon: Icon(
                        m.pinned ? Icons.push_pin : Icons.push_pin_outlined,
                        color: m.pinned ? c.pin : c.textSubtle,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (items.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(Space.md + 2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(Radii.button),
                border: Border.all(color: c.outline),
              ),
              child: Text(
                'Nothing here yet.',
                style: t.body.copyWith(color: c.textSubtle),
              ),
            ),
        ],
      ),
    );
  }
}
