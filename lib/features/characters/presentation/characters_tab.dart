import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/backend/backend_providers.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/hearth_theme.dart';
import '../../../core/widgets/overline.dart';
import '../../../core/widgets/refresh.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/util/greeting.dart';
import '../../../core/util/roleplay_parser.dart';
import '../../../core/util/time_label.dart';
import '../../../core/widgets/character_avatar.dart';
import '../../../core/widgets/chat_tile.dart';
import '../../../core/widgets/hearth_logo.dart';
import '../../../core/widgets/states.dart';
import '../../../data/mock/mock_scenario.dart';
import '../../chat/data/conversation_repository.dart';
import '../../chat/domain/chat_models.dart';
import '../../../core/widgets/toast.dart';
import '../../../data/mock/mock_data.dart';
import '../../library/data/sample_seed.dart';
import '../../chats/presentation/chat_actions.dart';
import 'character_actions.dart';
import '../data/character_repository.dart';
import '../data/draft_repository.dart';
import '../domain/character_form.dart';
import '../domain/character.dart';
import 'widgets/character_card.dart';
import 'widgets/character_grid.dart';

/// The Character Library (home). Open the app → pick a character → start
/// roleplaying; resuming is one tap on the Continue card.
///
/// Drafts (saved from the editor) are added in phase 4.
class CharactersTab extends ConsumerStatefulWidget {
  const CharactersTab({super.key});

  @override
  ConsumerState<CharactersTab> createState() => _CharactersTabState();
}

class _CharactersTabState extends ConsumerState<CharactersTab> {
  final _search = TextEditingController();
  String _query = '';
  bool _showArchived = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _retry() {
    ref.invalidate(charactersProvider);
    ref.invalidate(conversationsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final chars = ref.watch(charactersProvider);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const _Header(),
            const LoadingBar(),
            Expanded(
              child: chars.when(
                loading: () => const HomeSkeleton(),
                error: (_, _) => OfflineState(onRetry: _retry),
                data: (list) => list.isEmpty
                    ? FirstRunState(
                        icon: const HearthLogo(size: Sizes.logoSplash),
                        onMeetSamples: () async {
                          if (ref.read(usesBackendProvider)) {
                            // A new account starts empty: copy the sample stories into it.
                            try {
                              await seedSampleStories(ref);
                            } catch (_) {
                              if (context.mounted) {
                                showToast(
                                  context,
                                  'Couldn’t add them. Check your connection.',
                                );
                              }
                            }
                          } else {
                            ref.read(mockScenarioProvider.notifier).state =
                                MockScenario.normal;
                          }
                        },
                        onCreate: () => context.push(Routes.characterNew),
                      )
                    : _content(context, list),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _content(BuildContext context, List<Character> everyone) {
    // Archived characters and chats are hidden here (kept until deleted).
    final archived = [
      for (final c in everyone)
        if (c.archived) c,
    ];
    final all = [
      for (final c in everyone)
        if (!c.archived) c,
    ];
    final convs = [
      for (final c
          in ref.watch(conversationsProvider).valueOrNull ??
              const <Conversation>[])
        if (!c.archived &&
            everyone.any((x) => x.id == c.characterId && !x.archived))
          c,
    ];
    final byId = {for (final c in everyone) c.id: c};
    final q = _query.trim().toLowerCase();
    final results = q.isEmpty
        ? all
        : all.where((c) {
            return c.name.toLowerCase().contains(q) ||
                c.short.toLowerCase().contains(q) ||
                c.tags.any((t) => t.toLowerCase().contains(q));
          }).toList();

    // Distinct characters, most recently chatted with first.
    final recent = <Character>[];
    for (final c in convs) {
      final ch = byId[c.characterId];
      if (ch != null && !recent.contains(ch)) recent.add(ch);
    }

    final t = context.ht;
    final drafts = ref.watch(draftsProvider);
    return PullToRefresh(
      child: ListView(
        physics: refreshablePhysics,
        padding: const EdgeInsets.fromLTRB(
          Space.gutter,
          Space.sm,
          Space.gutter,
          Space.xxl,
        ),
        children: [
          // The greeting is a heading of its own, apart from the top bar.
          Padding(
            padding: const EdgeInsets.only(top: Space.sm, bottom: Space.lg),
            child: Text(greetingFor(DateTime.now()), style: t.display),
          ),
          _SearchField(
            controller: _search,
            onChanged: (v) => setState(() => _query = v),
            onClear: () => setState(() {
              _search.clear();
              _query = '';
            }),
          ),
          const SizedBox(height: Space.lg),
          if (q.isNotEmpty) ...[
            Overline(
              results.isEmpty
                  ? 'No matches'
                  : '${results.length} ${results.length == 1 ? 'match' : 'matches'}',
            ),
            const SizedBox(height: Space.md),
            if (results.isEmpty)
              _NoMatches(
                query: _query.trim(),
                onCreate: () => context.push(
                  Uri(
                    path: Routes.characterNew,
                    queryParameters: {'name': _query.trim()},
                  ).toString(),
                ),
              )
            else
              CharacterGrid(
                children: [
                  for (var i = 0; i < results.length; i++)
                    CharacterCard(
                      index: i,
                      character: results[i],
                      onTap: () =>
                          context.push(Routes.character(results[i].id)),
                      onMore: () =>
                          showCharacterOptions(context, ref, results[i]),
                    ),
                ],
              ),
          ] else ...[
            if (convs.isNotEmpty) ...[
              Overline('Continue chatting'),
              const SizedBox(height: Space.md),
              _conversationCard(context, convs.first, byId, large: true),
              for (var i = 1; i < convs.length && i < 3; i++) ...[
                const SizedBox(height: Space.sm),
                _conversationCard(context, convs[i], byId, index: i),
              ],
              const SizedBox(height: Space.xl),
            ],
            if (recent.isNotEmpty) ...[
              Overline('Your recent characters'),
              const SizedBox(height: Space.sm),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final c in recent.take(8))
                      _RecentAvatar(
                        character: c,
                        onTap: () => context.push(Routes.character(c.id)),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: Space.xl),
            ],
            Overline('Your characters'),
            const SizedBox(height: Space.md),
            CharacterGrid(
              children: [
                for (var i = 0; i < all.length; i++)
                  CharacterCard(
                    index: i,
                    character: all[i],
                    onTap: () => context.push(Routes.character(all[i].id)),
                    onMore: () => showCharacterOptions(context, ref, all[i]),
                  ),
                CreateCharacterCard(
                  index: all.length,
                  onTap: () => context.push(Routes.characterNew),
                ),
              ],
            ),
            if (archived.isNotEmpty) ...[
              const SizedBox(height: Space.xl),
              TextButton.icon(
                style: TextButton.styleFrom(
                  minimumSize: const Size.fromHeight(Hit.primary),
                  alignment: AlignmentDirectional.centerStart,
                ),
                onPressed: () => setState(() => _showArchived = !_showArchived),
                icon: Icon(
                  _showArchived ? Icons.expand_less : Icons.archive_outlined,
                ),
                label: Text(
                  _showArchived
                      ? 'Hide archived'
                      : 'Archived (${archived.length})',
                ),
              ),
              if (_showArchived)
                for (final ch in archived)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Space.sm),
                    child: ChatTile(
                      avatar: CharacterAvatar.of(ch, size: Sizes.avatar),
                      title: ch.name,
                      subtitle: 'Archived',
                      preview: ch.short,
                      onTap: () => context.push(Routes.character(ch.id)),
                      onMore: () => showCharacterOptions(context, ref, ch),
                      moreTooltip: 'More options for ${ch.first}',
                    ),
                  ),
            ],
            if (drafts.isNotEmpty) ...[
              const SizedBox(height: Space.xl),
              Overline('Drafts'),
              const SizedBox(height: Space.md),
              for (var i = 0; i < drafts.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: Space.sm),
                  child: _DraftRow(
                    index: i,
                    draft: drafts[i],
                    onTap: () => context.push(
                      drafts[i].editingId != null
                          ? Routes.characterEdit(
                              drafts[i].editingId!,
                              draft: drafts[i].id,
                            )
                          : Routes.draftNew(drafts[i].id),
                    ),
                    onDelete: () {
                      final notifier = ref.read(draftsProvider.notifier);
                      final removed = drafts[i];
                      notifier.remove(removed.id);
                      showToast(
                        context,
                        'Draft deleted',
                        onUndo: () => notifier.save(removed),
                      );
                    },
                  ),
                ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _conversationCard(
    BuildContext context,
    Conversation c,
    Map<String, Character> byId, {
    bool large = false,
    int index = 0,
  }) {
    final ch = byId[c.characterId];
    final who = ch?.first ?? 'Them';
    final avatar = ch == null
        ? const SizedBox.square(dimension: Sizes.avatar)
        : CharacterAvatar.of(
            ch,
            size: large ? Sizes.avatarLarge : Sizes.avatar,
          );
    final preview = stripRoleplay(c.last?.text ?? '');
    final subtitle = '$who · ${timeLabel(c.updatedAt)}';
    void open() => context.push(Routes.chat(c.id));
    return large
        ? ContinueCard(
            avatar: avatar,
            title: c.title,
            subtitle: subtitle,
            preview: preview,
            onTap: open,
            onMore: () => showChatOptions(context, ref, c),
          )
        : ChatTile(
            index: index,
            avatar: avatar,
            title: c.title,
            subtitle: subtitle,
            preview: preview,
            pinned: c.pinned,
            onTap: open,
            onMore: () => showChatOptions(context, ref, c),
            moreTooltip: 'More options for this chat',
          );
  }
}

/// The top bar: just the logo and the app name, plus the settings buttons.
/// (The greeting is its own heading below it.)
class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final t = context.ht;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.sm, 0),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                const HearthLogo(
                  size: Sizes.avatar - Space.sm,
                  semanticLabel: null,
                ),
                const SizedBox(width: Space.md),
                Flexible(
                  child: Text(
                    'Hearth',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.title.copyWith(fontSize: 24),
                  ),
                ),
              ],
            ),
          ),
          if (kDebugMode)
            IconButton(
              tooltip: 'Design reference',
              icon: const Icon(Icons.palette_outlined),
              onPressed: () => context.push(Routes.dev),
            ),
          const RefreshButton(),
          IconButton(
            tooltip: 'Profile and settings',
            icon: const Icon(Icons.account_circle_outlined),
            onPressed: () => context.push(Routes.settings),
          ),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      style: context.ht.chat,
      decoration: InputDecoration(
        hintText: 'Search characters or tags',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Clear search',
                icon: const Icon(Icons.close),
                onPressed: onClear,
              ),
        constraints: const BoxConstraints(minHeight: Hit.primary),
      ),
    );
  }
}

class _NoMatches extends StatelessWidget {
  const _NoMatches({required this.query, required this.onCreate});

  final String query;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Nobody here goes by “$query”. Want to make them?',
          style: context.ht.body.copyWith(color: context.hc.textMuted),
        ),
        const SizedBox(height: Space.lg),
        FilledButton(onPressed: onCreate, child: Text('Create “$query”')),
      ],
    );
  }
}

class _RecentAvatar extends StatelessWidget {
  const _RecentAvatar({required this.character, required this.onTap});

  final Character character;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Open ${character.first}’s profile',
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.card),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(Space.sm),
          child: SizedBox(
            width: Sizes.avatarLarge + Space.lg,
            child: Column(
              children: [
                CharacterAvatar.of(
                  character,
                  size: Sizes.avatarLarge,
                  shape: AvatarShape.circle,
                ),
                const SizedBox(height: Space.xs),
                Text(
                  character.first,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.ht.caption.copyWith(
                    color: context.hc.textMuted,
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

/// A saved, unfinished character. Tap to keep editing; ⋯ deletes it (with Undo).
class _DraftRow extends StatelessWidget {
  const _DraftRow({
    required this.index,
    required this.draft,
    required this.onTap,
    required this.onDelete,
  });

  final int index;
  final CharacterDraft draft;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final f = draft.form;
    final sw =
        MockData.swatches[f.swatch.clamp(0, MockData.swatches.length - 1)];
    final name = f.hasName ? f.name.trim() : 'Untitled character';
    return ChatTile(
      index: index,
      avatar: CharacterAvatar(
        tile: sw.tile,
        ink: sw.ink,
        initial: f.hasName ? f.first.substring(0, 1).toUpperCase() : '?',
        bytes: f.imageBytes,
        size: Sizes.avatar,
      ),
      title: name,
      subtitle: draft.editingId != null ? 'Draft changes' : 'Draft',
      preview: f.short.trim().isEmpty ? 'Tap to keep going' : f.short.trim(),
      onTap: onTap,
      onMore: onDelete,
      moreTooltip: 'Delete draft $name',
      moreIcon: Icons.delete_outline,
    );
  }
}
