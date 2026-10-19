import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';
import '../../../core/theme/hearth_theme.dart';
import '../../../core/widgets/overline.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/character_avatar.dart';
import '../../../core/widgets/motion_widgets.dart';
import '../../../core/widgets/states.dart';
import '../../../core/widgets/tap_card.dart';
import '../../../core/util/roleplay_parser.dart';
import '../../../core/util/time_label.dart';
import '../../../core/widgets/chat_tile.dart';
import '../../chats/presentation/chat_actions.dart';
import 'character_actions.dart';
import '../../chat/data/conversation_repository.dart';
import '../../chat/domain/chat_models.dart';
import '../../library/data/library_repository.dart';
import '../../relationship/data/relationship_providers.dart';
import '../data/character_repository.dart';
import '../domain/character.dart';

/// Character profile: portrait, description, tags, universe, relationship
/// journal, introduction and details. The bottom bar starts a new chat (2 taps
/// from the library) and offers a Resume link when a chat already exists.
class CharacterDetailsScreen extends ConsumerStatefulWidget {
  const CharacterDetailsScreen({super.key, required this.characterId});

  final String characterId;

  @override
  ConsumerState<CharacterDetailsScreen> createState() =>
      _CharacterDetailsScreenState();
}

class _CharacterDetailsScreenState
    extends ConsumerState<CharacterDetailsScreen> {
  bool _introOpen = false;
  bool _moreOpen = false;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(characterProvider(widget.characterId));
    return async.when(
      loading: () =>
          Scaffold(appBar: AppBar(), body: const SkeletonRows(count: 3)),
      error: (_, _) => Scaffold(
        appBar: AppBar(),
        body: OfflineState(onRetry: () => ref.invalidate(charactersProvider)),
      ),
      data: (ch) => ch == null
          ? Scaffold(
              appBar: AppBar(),
              body: EmptyState(
                title: 'We can’t find this character',
                primaryLabel: 'Back to characters',
                onPrimary: () => context.go(Routes.characters),
              ),
            )
          : _body(context, ch),
    );
  }

  Widget _body(BuildContext context, Character ch) {
    final c = context.hc;
    final t = context.ht;
    final convs =
        ref.watch(conversationsProvider).valueOrNull ?? const <Conversation>[];
    // All your chats with them, newest first. Resume picks the latest one that
    // is not archived.
    final chats = [
      for (final cv in convs)
        if (cv.characterId == ch.id) cv,
    ];
    Conversation? resume;
    for (final cv in chats) {
      if (!cv.archived) {
        resume = cv;
        break;
      }
    }
    final universes = ref.watch(universesProvider).valueOrNull;
    final stage = ref.watch(relationshipProvider(ch.id)).valueOrNull?.stageName;
    String? universeName;
    if (ch.universeId != null && universes != null) {
      for (final u in universes) {
        if (u.id == ch.universeId) universeName = u.name;
      }
    }

    return Scaffold(
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    _Hero(character: ch),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        Space.gutter,
                        Space.lg,
                        Space.gutter,
                        Space.xl,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(ch.name, style: t.display),
                          const SizedBox(height: Space.sm),
                          Text(
                            ch.short,
                            style: t.body.copyWith(color: c.textMuted),
                          ),
                          if (ch.tags.isNotEmpty) ...[
                            const SizedBox(height: Space.md),
                            Wrap(
                              spacing: Space.sm,
                              runSpacing: Space.sm,
                              children: [
                                for (final tag in ch.tags) _TagPill(tag),
                              ],
                            ),
                          ],
                          if (universeName != null) ...[
                            const SizedBox(height: Space.sm),
                            TextButton.icon(
                              onPressed: () =>
                                  context.push(Routes.universe(ch.universeId!)),
                              icon: const Icon(
                                Icons.public,
                                size: Space.xl - Space.xs,
                              ),
                              label: Text(
                                universeName,
                                overflow: TextOverflow.ellipsis,
                              ),
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                              ),
                            ),
                          ],
                          const SizedBox(height: Space.lg),
                          TapCard(
                            onTap: () =>
                                context.push(Routes.relationship(ch.id)),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.favorite_border,
                                  color: c.primaryInk,
                                ),
                                const SizedBox(width: Space.md),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Relationship journal',
                                        style: t.label,
                                      ),
                                      Text(
                                        stage == null
                                            ? 'How things stand between you and ${ch.first}'
                                            : '$stage · how things stand with ${ch.first}',
                                        style: t.caption,
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(Icons.chevron_right, color: c.textSubtle),
                              ],
                            ),
                          ),
                          if (chats.isNotEmpty) ...[
                            const SizedBox(height: Space.xl),
                            Overline(
                              chats.length == 1
                                  ? 'Chat with ${ch.first}'
                                  : 'Chats with ${ch.first} (${chats.length})',
                            ),
                            const SizedBox(height: Space.sm),
                            for (var i = 0; i < chats.length; i++)
                              Padding(
                                padding: const EdgeInsets.only(
                                  bottom: Space.sm,
                                ),
                                child: ChatTile(
                                  index: i,
                                  avatar: CharacterAvatar.of(
                                    ch,
                                    size: Sizes.avatar - 4,
                                  ),
                                  title: chats[i].title,
                                  subtitle: chats[i].archived
                                      ? 'Archived · ${timeLabel(chats[i].updatedAt)}'
                                      : timeLabel(chats[i].updatedAt),
                                  preview: stripRoleplay(
                                    chats[i].last?.text ?? '',
                                  ),
                                  pinned: chats[i].pinned,
                                  onTap: () =>
                                      context.push(Routes.chat(chats[i].id)),
                                  onMore: () =>
                                      showChatOptions(context, ref, chats[i]),
                                  moreTooltip: 'More options for this chat',
                                ),
                              ),
                          ],
                          const SizedBox(height: Space.xl),
                          Overline('Introduction'),
                          const SizedBox(height: Space.sm),
                          AnimatedSize(
                            duration: reduceMotion(context)
                                ? Duration.zero
                                : Motion.sheet,
                            curve: Motion.emphasizedDecelerate,
                            alignment: Alignment.topCenter,
                            child: Text(
                              ch.intro,
                              maxLines: _introOpen ? null : 3,
                              overflow: _introOpen
                                  ? TextOverflow.visible
                                  : TextOverflow.ellipsis,
                              style: t.story.copyWith(fontSize: 17),
                            ),
                          ),
                          TextButton(
                            onPressed: () =>
                                setState(() => _introOpen = !_introOpen),
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                            ),
                            child: Text(_introOpen ? 'Show less' : 'Read more'),
                          ),
                          const SizedBox(height: Space.md),
                          _MoreAbout(
                            character: ch,
                            open: _moreOpen,
                            onToggle: () =>
                                setState(() => _moreOpen = !_moreOpen),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              _BottomBar(
                resumeTitle: resume?.title,
                onResume: resume == null
                    ? null
                    : () => context.push(Routes.chat(resume!.id)),
                onEdit: () => context.push(Routes.characterEdit(ch.id)),
                onStart: () {
                  final id = ref
                      .read(conversationsProvider.notifier)
                      .startNew(ch);
                  context.push(Routes.chat(id));
                },
              ),
            ],
          ),
          // Pinned: the ⋯ menu (archive, delete) stays reachable too.
          Positioned(
            top: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(Space.sm),
                child: Material(
                  color: c.scrim,
                  shape: const CircleBorder(),
                  child: IconButton(
                    tooltip: 'More options',
                    icon: Icon(Icons.more_horiz, color: c.onScrim),
                    onPressed: () => showCharacterOptions(context, ref, ch),
                  ),
                ),
              ),
            ),
          ),
          // Pinned: Back stays reachable however far you scroll.
          Positioned(
            top: 0,
            left: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(Space.sm),
                child: Material(
                  color: c.scrim,
                  shape: const CircleBorder(),
                  child: IconButton(
                    tooltip: 'Back',
                    icon: Icon(Icons.arrow_back, color: c.onScrim),
                    onPressed: () => context.canPop()
                        ? context.pop()
                        : context.go(Routes.characters),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.character});

  final Character character;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        AspectRatio(
          aspectRatio: 1.25,
          child: CharacterAvatar.of(
            character,
            size: double.infinity,
            height: double.infinity,
            radius: 0,
            initialSize: Space.xxl * 3,
          ),
        ),
      ],
    );
  }
}

class _TagPill extends StatelessWidget {
  const _TagPill(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Space.md,
        vertical: Space.xs + 1,
      ),
      decoration: BoxDecoration(
        color: context.hc.surfaceRaised,
        borderRadius: BorderRadius.circular(Radii.card * 2),
      ),
      child: Text(
        label,
        style: context.ht.caption.copyWith(color: context.hc.textMuted),
      ),
    );
  }
}

class _MoreAbout extends StatelessWidget {
  const _MoreAbout({
    required this.character,
    required this.open,
    required this.onToggle,
  });

  final Character character;
  final bool open;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final c = context.hc;
    final t = context.ht;
    final rows = <(String, String)>[
      ('Personality', character.personality),
      ('Speaking style', character.speaking),
      ('Example dialogue', character.exampleDialogue),
      ('Always and never', character.rules),
      ('Relationships', character.relationships),
      ('Opening scenario', character.scenario),
    ].where((r) => r.$2.trim().isNotEmpty).toList();

    return Material(
      color: c.surface,
      borderRadius: BorderRadius.circular(Radii.card),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: true,
            expanded: open,
            label: 'More about ${character.first}',
            excludeSemantics: true,
            onTap: onToggle,
            child: InkWell(
              onTap: onToggle,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: Hit.primary + Space.xs,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Space.lg),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'More about ${character.first}',
                          style: t.body.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                      AnimatedRotation(
                        turns: open ? 0.5 : 0,
                        duration: reduceMotion(context)
                            ? Duration.zero
                            : Motion.press,
                        child: Icon(
                          Icons.keyboard_arrow_down,
                          color: c.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: reduceMotion(context) ? Duration.zero : Motion.sheet,
            curve: Motion.emphasizedDecelerate,
            alignment: Alignment.topCenter,
            child: open
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(
                      Space.lg,
                      0,
                      Space.lg,
                      Space.lg,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final r in rows) ...[
                          Overline(r.$1),
                          const SizedBox(height: Space.xs),
                          Text(
                            r.$2,
                            style: t.body.copyWith(color: c.textMuted),
                          ),
                          const SizedBox(height: Space.md),
                        ],
                      ],
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.resumeTitle,
    required this.onResume,
    required this.onEdit,
    required this.onStart,
  });

  final String? resumeTitle;
  final VoidCallback? onResume;
  final VoidCallback onEdit;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final c = context.hc;
    return Container(
      decoration: BoxDecoration(
        color: c.bg,
        border: Border(top: BorderSide(color: c.outline)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            Space.gutter,
            Space.sm,
            Space.gutter,
            Space.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (resumeTitle != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: onResume,
                    icon: const Icon(Icons.history, size: Space.xl - Space.xs),
                    label: Text(
                      'Resume “$resumeTitle”',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: Space.xs),
                    ),
                  ),
                ),
              Row(
                children: [
                  OutlinedButton(onPressed: onEdit, child: const Text('Edit')),
                  const SizedBox(width: Space.md),
                  Expanded(
                    child: FilledButton(
                      onPressed: onStart,
                      child: const Text('Start new chat'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
