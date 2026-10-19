import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/refresh.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/hearth_colors.dart';
import '../../../core/theme/hearth_text.dart';
import '../../../core/theme/hearth_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/controls.dart';
import '../../../core/widgets/overline.dart';
import '../../../core/widgets/states.dart';
import '../../../core/widgets/toast.dart';
import '../../characters/data/character_repository.dart';
import '../../characters/domain/character.dart';
import '../../library/data/library_repository.dart';
import '../../settings/data/app_prefs.dart';
import '../data/relationship_providers.dart';
import '../domain/relationship_bands.dart';
import '../domain/relationship_models.dart';
import 'relationship_sheets.dart';

void _back(BuildContext context, String characterId) => context.canPop()
    ? context.pop()
    : context.go(Routes.character(characterId));

/// The relationship journal: where things stand, why, and the full history.
/// You can correct anything. Numbers live here and nowhere in a chat.
class RelationshipJournalScreen extends ConsumerWidget {
  const RelationshipJournalScreen({
    super.key,
    required this.characterId,
    this.entryId,
  });

  final String characterId;

  /// A timeline entry to open and scroll to (from "Why?" under a message).
  final String? entryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ch = ref.watch(characterProvider(characterId));
    final rel = ref.watch(relationshipProvider(characterId));
    final character = ch.valueOrNull;
    final r = rel.valueOrNull;
    if (character == null || r == null) {
      final missing = ch.hasValue && character == null;
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Back',
            icon: const Icon(Icons.arrow_back),
            onPressed: () => _back(context, characterId),
          ),
        ),
        body: missing
            ? EmptyState(
                title: 'We can’t find this character',
                primaryLabel: 'Back to characters',
                onPrimary: () => context.go(Routes.characters),
              )
            : const SkeletonRows(count: 4),
      );
    }
    return _Journal(character: character, r: r, entryId: entryId);
  }
}

class _Journal extends ConsumerStatefulWidget {
  const _Journal({required this.character, required this.r, this.entryId});

  final Character character;
  final Relationship r;
  final String? entryId;

  @override
  ConsumerState<_Journal> createState() => _JournalState();
}

class _JournalState extends ConsumerState<_Journal> {
  late final Set<String> _open = {if (widget.entryId != null) widget.entryId!};
  final Map<String, GlobalKey> _keys = {};
  bool _showBlock = false;

  Character get ch => widget.character;
  Relationship get r => widget.r;
  RelationshipsNotifier get _notifier =>
      ref.read(relationshipsProvider.notifier);

  @override
  void initState() {
    super.initState();
    final id = widget.entryId;
    if (id != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = _keys[id]?.currentContext;
        if (ctx != null && mounted) {
          Scrollable.ensureVisible(
            ctx,
            duration: Motion.tab,
            curve: Motion.soft,
            alignment: 0.1,
          );
        }
      });
    }
  }

  GlobalKey _keyFor(String id) => _keys.putIfAbsent(id, GlobalKey.new);

  Future<void> _adjust() async {
    final res = await showAdjustSheet(context, r, ch.first);
    if (res == null || !mounted) return;
    await _notifier.correct(
      ch.id,
      res.values,
      reason: res.reason.trim().isEmpty ? null : res.reason.trim(),
    );
    if (mounted) {
      showToast(context, 'Correction saved — the next reply will reflect it');
    }
  }

  Future<void> _editStages() async {
    final res = await showStagesSheet(context, r);
    if (res == null || !mounted) return;
    await _notifier.saveStages(ch.id, res.names, res.current, res.lock);
    if (mounted) showToast(context, 'Stages saved');
  }

  Future<void> _addFact() async {
    final res = await showFactSheet(context);
    if (res == null || !mounted) return;
    await _notifier.addFact(ch.id, res.text, locked: res.locked);
  }

  Future<void> _removeFact(Fact f) async {
    await _notifier.removeFact(ch.id, f.id);
    if (!mounted) return;
    showToast(
      context,
      'Fact removed',
      onUndo: () => _notifier.addFact(ch.id, f.text, locked: f.locked),
    );
  }

  Future<void> _undo(RelationshipEvent e) async {
    await _notifier.undo(ch.id, e.id);
    if (mounted) showToast(context, 'Change undone');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.hc;
    final t = context.ht;
    final universes = ref.watch(universesProvider).valueOrNull ?? const [];
    String? universeName;
    for (final u in universes) {
      if (u.id == ch.universeId) universeName = u.name;
    }
    final romance = r.type.romanceAllowed;
    final notes = ref.watch(
      appPrefsProvider.select((p) => p.relationshipNotes),
    );

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => _back(context, ch.id),
        ),
        actions: [
          RefreshButton(
            onRefresh: () =>
                ref.read(relationshipsProvider.notifier).refresh(ch.id),
          ),
        ],
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Relationship journal', style: t.title.copyWith(fontSize: 18)),
            Text(
              'You & ${ch.first} · ${universeName ?? 'Standalone story'}',
              style: t.caption.copyWith(color: c.textMuted),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
      body: PullToRefresh(
        onRefresh: () =>
            ref.read(relationshipsProvider.notifier).refresh(ch.id),
        child: SingleChildScrollView(
          physics: refreshablePhysics,
          padding: const EdgeInsets.fromLTRB(
            Space.gutter,
            Space.sm,
            Space.gutter,
            Space.xxl,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: Reading.storyMaxWidth,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _stageHeader(c, t),
                  if (r.pending.isNotEmpty) ...[
                    const SizedBox(height: Space.xl),
                    _pending(c, t),
                  ],
                  const SizedBox(height: Space.xl),
                  _shapes(c, t),
                  const SizedBox(height: Space.xl),
                  _details(c, t, romance),
                  const SizedBox(height: Space.xl),
                  _pacing(c, t),
                  const SizedBox(height: Space.xl),
                  _kind(c, t),
                  const SizedBox(height: Space.xl),
                  _stages(c, t, romance),
                  const SizedBox(height: Space.xl),
                  _facts(c, t),
                  const SizedBox(height: Space.xl),
                  _timeline(c, t),
                  const SizedBox(height: Space.xl),
                  _duringRoleplay(c, t, notes),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── sections ──────────────────────────────────────────────────────────

  Widget _stageHeader(HearthColors c, HearthText t) {
    return Container(
      padding: const EdgeInsets.all(Space.lg),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: c.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Overline('Where you are'),
          const SizedBox(height: Space.sm),
          Text(r.stageName, style: t.display),
          const SizedBox(height: Space.sm),
          Wrap(
            spacing: Space.sm,
            runSpacing: Space.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _pill(c, t, r.type.label),
              _pill(c, t, r.pacing.label),
              if (r.stageLocked)
                _pill(c, t, 'Stage locked', icon: Icons.lock_outline),
            ],
          ),
          const SizedBox(height: Space.md),
          Text(nextHint(r), style: t.body.copyWith(color: c.textMuted)),
        ],
      ),
    );
  }

  Widget _pill(HearthColors c, HearthText t, String text, {IconData? icon}) =>
      Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Space.md,
          vertical: Space.xs,
        ),
        decoration: BoxDecoration(
          color: c.surfaceRaised,
          borderRadius: BorderRadius.circular(Radii.sheet),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: c.textMuted),
              const SizedBox(width: Space.xs),
            ],
            Flexible(
              child: Text(text, style: t.caption.copyWith(color: c.textMuted)),
            ),
          ],
        ),
      );

  Widget _pending(HearthColors c, HearthText t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Overline('Waiting for your approval'),
        const SizedBox(height: Space.sm),
        for (final s in r.pending)
          Container(
            margin: const EdgeInsets.only(bottom: Space.sm),
            padding: const EdgeInsets.all(Space.lg),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(Radii.card),
              border: Border.all(color: c.primaryInk),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.title, style: t.label),
                const SizedBox(height: Space.xs),
                Text(s.why, style: t.body.copyWith(color: c.textMuted)),
                const SizedBox(height: Space.xs),
                Text(
                  _deltaText(s.deltas),
                  style: t.caption.copyWith(color: c.textSubtle),
                ),
                const SizedBox(height: Space.sm),
                Row(
                  children: [
                    FilledButton(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(Hit.primary, Hit.inline),
                      ),
                      onPressed: () async {
                        await _notifier.acceptSuggestion(ch.id, s.id);
                        if (mounted) showToast(context, 'Change applied');
                      },
                      child: const Text('Apply'),
                    ),
                    const SizedBox(width: Space.sm),
                    TextButton(
                      style: TextButton.styleFrom(
                        minimumSize: const Size(Hit.primary, Hit.inline),
                      ),
                      onPressed: () async {
                        await _notifier.dismissSuggestion(ch.id, s.id);
                        if (mounted) showToast(context, 'Suggestion dismissed');
                      },
                      child: const Text('Dismiss'),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }

  String _deltaText(Map<RelValue, double> d) =>
      d.entries.map((e) => '${e.key.label} ${signed(e.value)}').join(' · ');

  Widget _shapes(HearthColors c, HearthText t) {
    final lines = behaviorLines(r);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Overline('How this shapes ${ch.first} right now'),
        const SizedBox(height: Space.sm),
        for (final l in lines)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(
                    top: Space.sm,
                    right: Space.md,
                  ),
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: c.primaryInk,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Expanded(child: Text(l, style: t.body)),
              ],
            ),
          ),
        TextButton.icon(
          style: TextButton.styleFrom(
            minimumSize: const Size(Hit.primary, Hit.inline),
            padding: EdgeInsets.zero,
            alignment: Alignment.centerLeft,
          ),
          onPressed: () => setState(() => _showBlock = !_showBlock),
          icon: Icon(
            _showBlock ? Icons.expand_less : Icons.expand_more,
            size: Space.xl,
          ),
          label: const Text('See exactly what the AI is told'),
        ),
        AnimatedSize(
          duration: Motion.tab,
          curve: Motion.soft,
          alignment: Alignment.topCenter,
          child: _showBlock
              ? Container(
                  padding: const EdgeInsets.all(Space.md),
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: BorderRadius.circular(Radii.field),
                    border: Border.all(color: c.outline),
                  ),
                  child: SelectableText(
                    promptBlock(r),
                    style: t.caption.copyWith(
                      fontFamily: 'monospace',
                      color: c.textMuted,
                      height: 1.5,
                    ),
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }

  Widget _details(HearthColors c, HearthText t, bool romance) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Overline('The details'),
            TextButton(
              style: TextButton.styleFrom(
                minimumSize: const Size(Hit.primary, Hit.inline),
              ),
              onPressed: _adjust,
              child: const Text('Adjust'),
            ),
          ],
        ),
        const SizedBox(height: Space.xs),
        for (final k in RelValue.values)
          _meter(c, t, k, off: k == RelValue.attraction && !romance),
        if (r.ignored > 0)
          Padding(
            padding: const EdgeInsets.only(top: Space.xs),
            child: Text(
              '${r.ignored} small ${r.ignored == 1 ? 'moment' : 'moments'} didn’t count — '
              'repeats and passing remarks don’t move things.',
              style: t.caption.copyWith(color: c.textSubtle),
            ),
          ),
      ],
    );
  }

  Widget _meter(HearthColors c, HearthText t, RelValue k, {required bool off}) {
    final v = r.values[k];
    final color = meterColor(context, k);
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.md),
      child: Semantics(
        label: off
            ? '${k.label}: not part of this relationship'
            : '${k.label}: ${wordFor(k, v)}, ${v.round()} out of 100',
        excludeSemantics: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: Space.md,
              children: [
                Text(k.label, style: t.label),
                Text(
                  off
                      ? 'Not part of this relationship'
                      : '${wordFor(k, v)} · ${v.round()}',
                  style: t.caption.copyWith(color: off ? c.textSubtle : color),
                ),
              ],
            ),
            const SizedBox(height: Space.xs + 2),
            ClipRRect(
              borderRadius: BorderRadius.circular(Radii.sheet),
              child: Container(
                height: Space.sm,
                color: c.surfaceRaised,
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: off ? 0 : (v / 100).clamp(0.0, 1.0),
                  child: Container(color: color),
                ),
              ),
            ),
            const SizedBox(height: Space.xs),
            Text(k.help, style: t.caption.copyWith(color: c.textSubtle)),
          ],
        ),
      ),
    );
  }

  Widget _pacing(HearthColors c, HearthText t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Overline('Pacing'),
        const SizedBox(height: Space.sm),
        HearthSegmented<RelPacing>(
          semanticLabel: 'Pacing',
          options: {for (final p in RelPacing.values) p: p.label},
          value: r.pacing,
          onChanged: (p) => _notifier.setPacing(ch.id, p),
        ),
        const SizedBox(height: Space.sm),
        Text(r.pacing.hint, style: t.caption.copyWith(color: c.textMuted)),
      ],
    );
  }

  Widget _kind(HearthColors c, HearthText t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Overline('Kind of relationship'),
        const SizedBox(height: Space.sm),
        Wrap(
          spacing: Space.sm,
          children: [
            for (final k in RelationType.values)
              HearthChip(
                label: k.label,
                selected: r.type == k,
                onTap: () async {
                  if (r.type == k) return;
                  final hadRomance = r.type.romanceAllowed;
                  await _notifier.setType(ch.id, k);
                  if (mounted && hadRomance && !k.romanceAllowed) {
                    showToast(
                      context,
                      'Romance is off. Attraction no longer shapes the story.',
                    );
                  }
                },
              ),
          ],
        ),
        const SizedBox(height: Space.sm),
        Text(typeHint(r.type), style: t.caption.copyWith(color: c.textMuted)),
      ],
    );
  }

  Widget _stages(HearthColors c, HearthText t, bool romance) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Overline('Stages'),
            TextButton(
              style: TextButton.styleFrom(
                minimumSize: const Size(Hit.primary, Hit.inline),
              ),
              onPressed: _editStages,
              child: const Text('Edit stages'),
            ),
          ],
        ),
        for (var i = 0; i < r.stages.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: Space.xs + 1),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(
                    top: Space.xs + 2,
                    right: Space.md,
                  ),
                  child: Container(
                    width: Space.md,
                    height: Space.md,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i <= r.stageIdx
                          ? c.primaryInk
                          : Colors.transparent,
                      border: Border.all(
                        color: i <= r.stageIdx ? c.primaryInk : c.outline,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r.stages[i],
                        style: t.body.copyWith(
                          color: i == r.stageIdx ? c.text : c.textMuted,
                          fontWeight: i == r.stageIdx
                              ? FontWeight.w700
                              : FontWeight.w400,
                        ),
                      ),
                      if (i == r.stageIdx)
                        Text(
                          'You are here',
                          style: t.caption.copyWith(color: c.primaryInk),
                        ),
                      if (r.romanticFrom != null && i == r.romanticFrom)
                        Text(
                          romance
                              ? 'Needs romance to grow first.'
                              : 'Out of reach while romance is off.',
                          style: t.caption.copyWith(color: c.textSubtle),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: Space.md),
        Text(
          'Start from a preset, then rename anything:',
          style: t.caption.copyWith(color: c.textMuted),
        ),
        const SizedBox(height: Space.xs),
        Wrap(
          spacing: Space.sm,
          children: [
            for (final p in stagePresets)
              HearthChip(
                label: p.label,
                onTap: () async {
                  await _notifier.applyPreset(ch.id, p.id);
                  if (mounted) showToast(context, 'Stages set to ${p.label}');
                },
              ),
          ],
        ),
      ],
    );
  }

  Widget _facts(HearthColors c, HearthText t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Overline('Established facts'),
            TextButton(
              style: TextButton.styleFrom(
                minimumSize: const Size(Hit.primary, Hit.inline),
              ),
              onPressed: _addFact,
              child: const Text('Add'),
            ),
          ],
        ),
        if (r.facts.isEmpty)
          Text(
            'No facts yet. Add things that must always stay true between you.',
            style: t.body.copyWith(color: c.textMuted),
          ),
        for (final f in r.facts)
          Container(
            margin: const EdgeInsets.only(bottom: Space.sm),
            padding: const EdgeInsets.only(left: Space.lg),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(Radii.field),
              border: Border.all(color: c.outline),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: Space.md),
                    child: Text(f.text, style: t.body),
                  ),
                ),
                IconButton(
                  tooltip: f.locked
                      ? 'Locked. Tap to unlock'
                      : 'Unlocked. Tap to lock',
                  constraints: const BoxConstraints(
                    minWidth: Hit.inline,
                    minHeight: Hit.inline,
                  ),
                  icon: Icon(
                    f.locked ? Icons.lock : Icons.lock_open,
                    size: Space.xl - Space.xs,
                    color: f.locked ? c.primaryInk : c.textSubtle,
                  ),
                  onPressed: () =>
                      _notifier.setFactLocked(ch.id, f.id, !f.locked),
                ),
                IconButton(
                  tooltip: 'Remove fact',
                  constraints: const BoxConstraints(
                    minWidth: Hit.inline,
                    minHeight: Hit.inline,
                  ),
                  icon: Icon(
                    Icons.close,
                    size: Space.xl - Space.xs,
                    color: c.textSubtle,
                  ),
                  onPressed: () => _removeFact(f),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Color _kindColor(HearthColors c, TimelineKind k) => switch (k) {
    TimelineKind.milestone => c.primaryInk,
    TimelineKind.setback => c.danger,
    TimelineKind.reconcile => c.ok,
    TimelineKind.shift => c.textMuted,
    TimelineKind.correction => c.textMuted,
  };

  Widget _timeline(HearthColors c, HearthText t) {
    final now = DateTime.now();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Overline('Timeline'),
        const SizedBox(height: Space.sm),
        if (r.events.isEmpty)
          Text(
            'Nothing has changed yet. Moments that matter will appear here.',
            style: t.body.copyWith(color: c.textMuted),
          ),
        for (final e in r.events) _entry(c, t, e, now),
      ],
    );
  }

  Widget _entry(
    HearthColors c,
    HearthText t,
    RelationshipEvent e,
    DateTime now,
  ) {
    final open = _open.contains(e.id);
    final struck = e.isUndone;
    final titleStyle = t.label.copyWith(
      color: struck ? c.textSubtle : c.text,
      decoration: struck ? TextDecoration.lineThrough : null,
    );
    return Container(
      key: _keyFor(e.id),
      margin: const EdgeInsets.only(bottom: Space.sm),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(Radii.field),
        border: Border.all(color: open ? c.primaryInk : c.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: true,
            expanded: open,
            label: '${e.category.label}. ${e.title}. ${dayLabel(e.at, now)}',
            excludeSemantics: true,
            onTap: () =>
                setState(() => open ? _open.remove(e.id) : _open.add(e.id)),
            child: InkWell(
              borderRadius: BorderRadius.circular(Radii.field),
              onTap: () =>
                  setState(() => open ? _open.remove(e.id) : _open.add(e.id)),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: Hit.primary),
                child: Padding(
                  padding: const EdgeInsets.all(Space.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              e.category.label.toUpperCase(),
                              style: t.overline.copyWith(
                                color: struck
                                    ? c.textSubtle
                                    : _kindColor(c, e.category),
                              ),
                            ),
                          ),
                          Text(
                            dayLabel(e.at, now),
                            style: t.caption.copyWith(color: c.textSubtle),
                          ),
                          Icon(
                            open ? Icons.expand_less : Icons.expand_more,
                            size: Space.xl - Space.xs,
                            color: c.textSubtle,
                          ),
                        ],
                      ),
                      const SizedBox(height: Space.xs),
                      Text(e.title, style: titleStyle),
                      const SizedBox(height: Space.xs),
                      Wrap(
                        spacing: Space.sm,
                        runSpacing: Space.xs,
                        children: [
                          for (final d in e.deltas.entries)
                            _chip(c, t, '${d.key.label} ${signed(d.value)}'),
                          if (e.fromDeletedChat)
                            _chip(c, t, 'from a deleted chat'),
                          if (e.stageBefore != null &&
                              e.stageAfter != null &&
                              e.stageBefore != e.stageAfter)
                            _chip(
                              c,
                              t,
                              '${r.stages[e.stageBefore!.clamp(0, r.stages.length - 1)]} → '
                              '${r.stages[e.stageAfter!.clamp(0, r.stages.length - 1)]}',
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: Motion.tab,
            curve: Motion.soft,
            alignment: Alignment.topCenter,
            child: open
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(
                      Space.md,
                      0,
                      Space.md,
                      Space.md,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Why it changed',
                          style: t.label.copyWith(
                            fontSize: 13,
                            color: c.textMuted,
                          ),
                        ),
                        const SizedBox(height: Space.xs),
                        Text(e.why, style: t.body),
                        if (e.evidence != null) ...[
                          const SizedBox(height: Space.xs),
                          Text(
                            '“${e.evidence}”',
                            style: t.body.copyWith(
                              fontStyle: FontStyle.italic,
                              color: c.textMuted,
                            ),
                          ),
                        ],
                        const SizedBox(height: Space.sm),
                        Text(
                          'Decided by: ${e.source.label}',
                          style: t.caption.copyWith(color: c.textSubtle),
                        ),
                        Text(
                          'In: ${e.chatTitle}',
                          style: t.caption.copyWith(color: c.textSubtle),
                        ),
                        if (struck)
                          Padding(
                            padding: const EdgeInsets.only(top: Space.sm),
                            child: Text(
                              'You undid this change.',
                              style: t.caption.copyWith(color: c.textMuted),
                            ),
                          ),
                        if (e.canUndo)
                          Padding(
                            padding: const EdgeInsets.only(top: Space.xs),
                            child: TextButton(
                              style: TextButton.styleFrom(
                                minimumSize: const Size(
                                  Hit.primary,
                                  Hit.inline,
                                ),
                                padding: EdgeInsets.zero,
                                alignment: Alignment.centerLeft,
                              ),
                              onPressed: () => _undo(e),
                              child: const Text('Undo this change'),
                            ),
                          ),
                      ],
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }

  Widget _chip(HearthColors c, HearthText t, String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: Space.sm, vertical: 2),
    decoration: BoxDecoration(
      color: c.surfaceRaised,
      borderRadius: BorderRadius.circular(Radii.sheet),
    ),
    child: Text(text, style: t.caption.copyWith(color: c.textMuted)),
  );

  Widget _duringRoleplay(
    HearthColors c,
    HearthText t,
    RelationshipNotes notes,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Overline('During roleplay'),
        const SizedBox(height: Space.sm),
        HearthSegmented<RelationshipNotes>(
          semanticLabel: 'During roleplay',
          options: {for (final n in RelationshipNotes.values) n: n.label},
          value: notes,
          onChanged: (n) =>
              ref.read(appPrefsProvider.notifier).setRelationshipNotes(n),
        ),
        const SizedBox(height: Space.sm),
        Text(
          notes == RelationshipNotes.subtle
              ? 'A quiet line appears under a message when something shifts between you. Tap it to see why. Numbers never appear in a chat.'
              : 'Nothing appears in the chat. Changes still happen and are recorded here.',
          style: t.caption.copyWith(color: c.textMuted),
        ),
      ],
    );
  }
}
