import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';
import '../../../core/theme/hearth_theme.dart';
import '../../../core/widgets/overline.dart';
import '../../../core/widgets/refresh.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/util/roleplay_parser.dart';
import '../../../core/util/time_label.dart';
import '../../../core/widgets/character_avatar.dart';
import '../../../core/widgets/chat_tile.dart';
import '../../../core/widgets/states.dart';
import 'chat_actions.dart';
import '../../../core/widgets/controls.dart';
import '../../characters/data/character_repository.dart';
import '../../characters/domain/character.dart';
import '../../chat/data/conversation_repository.dart';
import '../../chat/domain/chat_models.dart';
import '../../chat/presentation/chat_screen.dart';

/// Your conversations: search, Pinned and Recent, and a ⋯ on each row (Pin,
/// Rename, Delete with confirmation). From 840dp wide the open chat appears
/// beside the list (list-detail).
class ChatsTab extends ConsumerStatefulWidget {
  const ChatsTab({super.key});

  @override
  ConsumerState<ChatsTab> createState() => _ChatsTabState();
}

class _ChatsTabState extends ConsumerState<ChatsTab> {
  final _search = TextEditingController();
  String _query = '';

  /// The chat open in the detail pane (wide layout only).
  String? _selected;

  /// Showing archived chats instead of the active ones.
  bool _showArchived = false;

  static const double _listPaneWidth = 380;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool get _wide => MediaQuery.sizeOf(context).width >= Breakpoints.expanded;

  void _open(Conversation c) {
    if (_wide) {
      setState(() => _selected = c.id);
    } else {
      context.push(Routes.chat(c.id));
    }
  }

  Future<void> _options(Conversation c) => showChatOptions(
    context,
    ref,
    c,
    onDeleted: () {
      if (_selected == c.id) setState(() => _selected = null);
    },
  );

  @override
  Widget build(BuildContext context) {
    final list = _list(context);
    if (!_wide) return Scaffold(body: SafeArea(bottom: false, child: list));

    final id = _selected;
    final stillThere =
        id != null && ref.watch(conversationProvider(id)) != null;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Row(
          children: [
            SizedBox(width: _listPaneWidth, child: list),
            VerticalDivider(width: 1, color: context.hc.outline),
            Expanded(
              child: stillThere
                  ? ChatScreen(
                      key: ValueKey(id),
                      conversationId: id,
                      embedded: true,
                      onClose: () => setState(() => _selected = null),
                      onOpenConversation: (n) => setState(() => _selected = n),
                    )
                  : const EmptyState(
                      title: 'Choose a chat',
                      message: 'Your conversation will open here.',
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _list(BuildContext context) {
    final convs = ref.watch(conversationsProvider);
    final chars =
        ref.watch(charactersProvider).valueOrNull ?? const <Character>[];
    final byId = {for (final c in chars) c.id: c};

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Space.gutter,
            Space.xl,
            Space.gutter,
            Space.sm,
          ),
          child: Row(
            children: [
              Expanded(child: Text('Chats', style: context.ht.display)),
              const RefreshButton(),
            ],
          ),
        ),
        const LoadingBar(),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Space.gutter,
            0,
            Space.gutter,
            Space.sm,
          ),
          child: TextField(
            controller: _search,
            onChanged: (v) => setState(() => _query = v),
            textInputAction: TextInputAction.search,
            style: context.ht.chat,
            decoration: InputDecoration(
              hintText: 'Search chats',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() {
                        _search.clear();
                        _query = '';
                      }),
                    ),
              constraints: const BoxConstraints(minHeight: Hit.primary),
            ),
          ),
        ),
        Expanded(
          child: convs.when(
            loading: () => const SkeletonRows(),
            error: (_, _) => Column(
              children: [
                const OfflineBanner(),
                Expanded(
                  child: EmptyState(
                    title: 'No connection',
                    message:
                        'Your chats will show up here once you’re back online.',
                    primaryLabel: 'Try again',
                    onPrimary: () => ref.invalidate(conversationsProvider),
                  ),
                ),
              ],
            ),
            data: (all) => _body(context, all, byId),
          ),
        ),
      ],
    );
  }

  Widget _body(
    BuildContext context,
    List<Conversation> all,
    Map<String, Character> byId,
  ) {
    final archivedCount = all.where((c) => c.archived).length;
    final inView = [
      for (final c in all)
        if (c.archived == _showArchived) c,
    ];
    final q = _query.trim().toLowerCase();
    final shown = q.isEmpty
        ? inView
        : inView.where((c) {
            final ch = byId[c.characterId];
            return c.title.toLowerCase().contains(q) ||
                (ch?.name.toLowerCase().contains(q) ?? false) ||
                c.messages.any((m) => m.text.toLowerCase().contains(q));
          }).toList();

    final filter = Padding(
      padding: const EdgeInsets.fromLTRB(
        Space.gutter,
        0,
        Space.gutter,
        Space.sm,
      ),
      child: Wrap(
        spacing: Space.sm,
        children: [
          HearthChip(
            label: 'Chats',
            selected: !_showArchived,
            onTap: () => setState(() => _showArchived = false),
          ),
          HearthChip(
            icon: Icons.archive_outlined,
            label: archivedCount == 0
                ? 'Archived'
                : 'Archived ($archivedCount)',
            selected: _showArchived,
            onTap: () => setState(() => _showArchived = true),
          ),
        ],
      ),
    );

    if (shown.isEmpty) {
      return Column(
        children: [
          filter,
          Expanded(
            child: _showArchived && q.isEmpty
                ? const EmptyState(
                    title: 'Nothing archived',
                    message: 'Archive a chat from its ⋯ menu to tuck it away without deleting it.',
                  )
                : EmptyState(
                    title: q.isEmpty ? 'No chats yet' : 'No chats match',
                    message: q.isEmpty
                        ? 'Start a conversation with any character and it will live here.'
                        : 'Try a character name or a word from the conversation.',
                    primaryLabel: 'Browse characters',
                    onPrimary: () => context.go(Routes.characters),
                  ),
          ),
        ],
      );
    }

    final pinned = shown.where((c) => c.pinned).toList();
    final recent = shown.where((c) => !c.pinned).toList();
    var n = 0;

    Widget tile(Conversation c) {
      final ch = byId[c.characterId];
      return Padding(
        padding: const EdgeInsets.only(bottom: Space.sm),
        child: ChatTile(
          index: n++,
          selected: _wide && _selected == c.id,
          avatar: ch == null
              ? const SizedBox.square(dimension: Sizes.avatar)
              : CharacterAvatar.of(ch, size: Sizes.avatar),
          title: c.title,
          subtitle: '${ch?.first ?? 'Them'} · ${timeLabel(c.updatedAt)}',
          preview: stripRoleplay(c.last?.text ?? ''),
          pinned: c.pinned,
          onTap: () => _open(c),
          onMore: () => _options(c),
        ),
      );
    }

    return Column(
      children: [
        filter,
        Expanded(
          child: PullToRefresh(
            child: ListView(
              physics: refreshablePhysics,
              padding: const EdgeInsets.fromLTRB(
                Space.gutter,
                Space.sm,
                Space.gutter,
                Space.xxl,
              ),
              children: [
                if (pinned.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: Space.sm),
                    child: Overline('Pinned'),
                  ),
                  for (final c in pinned) tile(c),
                  const SizedBox(height: Space.md),
                ],
                if (recent.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: Space.sm),
                    child: Overline('Recent'),
                  ),
                  for (final c in recent) tile(c),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
