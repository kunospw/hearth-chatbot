import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/backend/backend_providers.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/hearth_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/util/roleplay_parser.dart';
import '../../../core/widgets/character_avatar.dart';
import '../../../core/widgets/composer.dart';
import '../../../core/widgets/inline_notice.dart';
import '../../../core/widgets/jump_to_latest_pill.dart';
import '../../../core/widgets/message_actions.dart';
import '../../../core/widgets/motion_widgets.dart';
import '../../../core/widgets/rich_roleplay_text.dart';
import '../../../core/widgets/sheets.dart';
import '../../../core/widgets/states.dart';
import '../../../core/widgets/toast.dart';
import '../../characters/data/character_repository.dart';
import '../../characters/domain/character.dart';
import '../../library/data/library_repository.dart';
import '../../relationship/data/relationship_providers.dart';
import '../../relationship/presentation/relationship_note_widgets.dart';
import '../../settings/data/app_prefs.dart';
import '../../settings/data/model_usage.dart';
import '../../settings/data/reading_prefs.dart';
import '../../settings/presentation/model_picker.dart';
import '../../settings/presentation/reading_sheet.dart';
import '../data/chat_controller.dart';
import '../data/conversation_repository.dart';
import '../domain/chat_models.dart';
import 'chat_tools_row.dart';
import 'message_list.dart';
import 'message_views.dart';

/// Chat and Story are two views of one route: the mode is a per-conversation
/// state, never a new route. Switching keeps the reading position.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({
    super.key,
    required this.conversationId,
    this.embedded = false,
    this.onClose,
    this.onOpenConversation,
  });

  final String conversationId;

  /// Shown inside the wide Chats layout: no Back button, and leaving the chat
  /// (delete, new chat) goes through the callbacks instead of the router.
  final bool embedded;
  final VoidCallback? onClose;
  final ValueChanged<String>? onOpenConversation;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

/// While the reader is scrolled up during a reply, the message being written
/// is shown as it was when they scrolled away, so nothing moves under them.
class _Freeze {
  const _Freeze(this.activeId, this.snapshot);
  final String activeId;
  final Message? snapshot;
}

enum _ConvoOption {
  allChats,
  journal,
  mode,
  reading,
  memories,
  model,
  rename,
  newChat,
  delete,
}

enum _MsgOption { copy, edit, rewrite, resend }

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _chatListKey = GlobalKey<MessageListState>(debugLabel: 'chat-list');
  final _storyListKey = GlobalKey<MessageListState>(debugLabel: 'story-list');
  final _focus = FocusNode();
  final _composer = TextEditingController();

  ScrollAnchor? _pendingAnchor;
  bool _near = true;
  bool _unseen = false;
  _Freeze? _freeze;
  String? _editingId;

  String get _id => widget.conversationId;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocus);
    // A toast from the previous screen must not sit on top of the composer.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
      // A chat remembers who you play as in it.
      final pid = ref.read(conversationProvider(_id))?.personaId;
      final known = ref.read(personasProvider).valueOrNull?.any((p) => p.id == pid) ?? false;
      if (pid != null && known && pid != ref.read(activePersonaIdProvider)) {
        ref.read(selectedPersonaIdProvider.notifier).select(pid);
      }
      // With a server, another device may have continued this chat.
      if (ref.read(usesBackendProvider) &&
          !ref.read(chatControllerProvider(_id)).busy) {
        unawaited(
          ref
              .read(conversationsProvider.notifier)
              .reload(_id)
              .catchError((Object _) {}),
        );
      }
    });
  }

  @override
  void dispose() {
    _focus
      ..removeListener(_onFocus)
      ..dispose();
    _composer.dispose();
    super.dispose();
  }

  /// When the composer gets focus, wait ~300ms for the keyboard, then jump to
  /// the latest message, but only if the reader is already near it.
  void _onFocus() {
    if (!_focus.hasFocus) return;
    Future<void>.delayed(const Duration(milliseconds: 300), () {
      if (!mounted || !_near) return;
      _list(ref.read(conversationProvider(_id))?.mode)?.scrollToBottom();
    });
  }

  MessageListState? _list(ChatMode? mode) =>
      (mode == ChatMode.story ? _storyListKey : _chatListKey).currentState;

  // ── content changes while the reader is away ──────────────────────────

  /// Starts holding the view still while a reply is written below the reader.
  /// [snapshotFrom] is the conversation as the reader last saw it.
  void _freezeIfAway(String? activeId, {Conversation? snapshotFrom}) {
    if (_near || _freeze != null || activeId == null) return;
    final conv = snapshotFrom ?? ref.read(conversationProvider(_id));
    if (conv == null || conv.mode != ChatMode.chat) return;
    Message? snap;
    for (final m in conv.messages) {
      if (m.id == activeId) snap = m;
    }
    setState(() {
      _unseen = true;
      _freeze = _Freeze(activeId, snap);
    });
  }

  void _onConversation(Conversation? prev, Conversation? next) {
    if (prev == null || next == null || _near) return;
    final ui = ref.read(chatControllerProvider(_id));
    if (!ui.busy) return;
    // The reader scrolled away mid-reply: freeze as they last saw it (prev).
    if (next.mode == ChatMode.chat && _freeze == null) {
      _freezeIfAway(ui.activeId, snapshotFrom: prev);
    } else if (!_unseen) {
      setState(() => _unseen = true);
    }
  }

  void _onNearBottom(bool near) {
    _near = near;
    if (near && (_unseen || _freeze != null)) {
      setState(() {
        _unseen = false;
        _freeze = null;
      });
    }
  }

  List<Message> _display(List<Message> live) {
    final f = _freeze;
    if (f == null) return live;
    return [
      for (final m in live)
        if (m.id == f.activeId) ...[if (f.snapshot != null) f.snapshot!] else m,
    ];
  }

  // ── actions ───────────────────────────────────────────────────────────

  bool get _animate => !reduceMotion(context);

  bool _hideNotes = false;

  ChatController get _ctl => ref.read(chatControllerProvider(_id).notifier);

  void _send(String text, ChatMode mode) {
    _list(mode)?.scrollToBottom();
    setState(() {
      _freeze = null;
      _unseen = false;
      _editingId = null;
    });
    if (mode == ChatMode.story && text.isEmpty) {
      _ctl.continueStory(animate: _animate);
    } else {
      _ctl.send(text, animate: _animate);
    }
  }

  void _stop() {
    if (_ctl.stop() != StopResult.none) {
      showToast(context, 'Stopped. Keep it, edit it, or rewrite it.');
    }
  }

  void _copy(Message m) {
    Clipboard.setData(ClipboardData(text: stripRoleplay(m.text)));
    showToast(context, 'Copied to clipboard');
  }

  void _saveEdit(Message m, String text) {
    if (!_ctl.edit(m.id, text)) {
      showToast(context, 'A message can’t be empty');
      return;
    }
    setState(() => _editingId = null);
    showToast(context, 'Message updated');
  }

  void _switchMode(ChatMode to) {
    final from = ref.read(conversationProvider(_id))?.mode;
    _pendingAnchor = _list(from)?.captureAnchor();
    setState(() {
      _freeze = null;
      _unseen = false;
      _near = true;
    });
    ref.read(conversationsProvider.notifier).setMode(_id, to);
  }

  Future<void> _messageOptions(Message m, {required bool latestAi}) async {
    final busy = ref.read(chatControllerProvider(_id)).busy;
    // Your last message, with no reply after it: offer to send it again.
    final unanswered =
        m.isUser &&
        ref.read(conversationProvider(_id))?.messages.lastOrNull?.id == m.id;
    final choice = await showOptionsSheet<_MsgOption>(
      context,
      options: [
        if (unanswered && !busy)
          const SheetOption(
            value: _MsgOption.resend,
            label: 'Send again',
            icon: Icons.send_outlined,
          ),
        const SheetOption(
          value: _MsgOption.copy,
          label: 'Copy',
          icon: Icons.copy_outlined,
        ),
        if (!busy)
          const SheetOption(
            value: _MsgOption.edit,
            label: 'Edit',
            icon: Icons.edit_outlined,
          ),
        if (latestAi && !busy)
          const SheetOption(
            value: _MsgOption.rewrite,
            label: 'Rewrite',
            icon: Icons.refresh,
          ),
      ],
    );
    if (!mounted || choice == null) return;
    switch (choice) {
      case _MsgOption.copy:
        _copy(m);
      case _MsgOption.edit:
        setState(() => _editingId = m.id);
      case _MsgOption.rewrite:
        _ctl.rewrite(m.id, animate: _animate);
      case _MsgOption.resend:
        _ctl.resend(animate: _animate);
    }
  }

  Future<void> _conversationOptions(Conversation conv, Character ch) async {
    final prefs = ref.read(readingPrefsProvider);
    final model = ref.read(selectedModelProvider);
    final story = conv.mode == ChatMode.story;
    final universeId = ch.universeId;
    final stageName = ref
        .read(relationshipProvider(ch.id))
        .valueOrNull
        ?.stageName;
    final choice = await showOptionsSheet<_ConvoOption>(
      context,
      title: 'Conversation options',
      options: [
        SheetOption(
          value: _ConvoOption.allChats,
          label: 'All chats with ${ch.first}',
          icon: Icons.forum_outlined,
        ),
        SheetOption(
          value: _ConvoOption.journal,
          label: 'Relationship journal',
          icon: Icons.favorite_border,
          meta: stageName,
        ),
        SheetOption(
          value: _ConvoOption.mode,
          label: story ? 'Switch to Chat mode' : 'Switch to Story mode',
          icon: story ? Icons.chat_bubble_outline : Icons.auto_stories_outlined,
        ),
        SheetOption(
          value: _ConvoOption.reading,
          label: 'Text size & reading',
          icon: Icons.text_fields,
          meta: '${(story ? prefs.storySize : prefs.chatSize).round()} pt',
        ),
        SheetOption(
          value: _ConvoOption.memories,
          label: 'Memories in this world',
          icon: Icons.bookmark_border,
          meta: universeId == null ? 'No universe' : null,
        ),
        SheetOption(
          value: _ConvoOption.model,
          label: 'Change AI model',
          icon: Icons.bolt_outlined,
          meta: model.name,
        ),
        const SheetOption(
          value: _ConvoOption.rename,
          label: 'Rename chat',
          icon: Icons.edit_outlined,
        ),
        SheetOption(
          value: _ConvoOption.newChat,
          label: 'Start a new chat with ${ch.first}',
          icon: Icons.add_comment_outlined,
        ),
        const SheetOption(
          value: _ConvoOption.delete,
          label: 'Delete chat…',
          icon: Icons.delete_outline,
          destructive: true,
        ),
      ],
    );
    if (!mounted || choice == null) return;
    switch (choice) {
      case _ConvoOption.allChats:
        context.push(Routes.character(ch.id));
      case _ConvoOption.journal:
        context.push(Routes.relationship(ch.id));
      case _ConvoOption.mode:
        _switchMode(story ? ChatMode.chat : ChatMode.story);
      case _ConvoOption.reading:
        showReadingSheet(context, conv.mode);
      case _ConvoOption.memories:
        if (universeId == null) {
          showToast(context, '${ch.first} isn’t part of a universe yet.');
        } else {
          context.push(Routes.universeMemories(universeId));
        }
      case _ConvoOption.model:
        _switchModel(retry: false);
      case _ConvoOption.rename:
        final name = await showTextInputSheet(
          context,
          title: 'Rename chat',
          initial: conv.title,
          confirmLabel: 'Save',
        );
        if (!mounted || name == null) return;
        ref.read(conversationsProvider.notifier).rename(_id, name);
        showToast(context, 'Renamed');
      case _ConvoOption.newChat:
        final id = ref.read(conversationsProvider.notifier).startNew(ch);
        if (widget.embedded) {
          widget.onOpenConversation?.call(id);
        } else {
          context.pushReplacement(Routes.chat(id));
        }
      case _ConvoOption.delete:
        final ok = await showConfirmDeleteSheet(
          context,
          title: 'Delete this chat?',
          message:
              'The whole conversation will be removed. This can’t be undone.',
          keepLabel: 'Keep chat',
          deleteLabel: 'Delete chat',
        );
        if (!ok || !mounted) return;
        final notifier = ref.read(conversationsProvider.notifier);
        final router = GoRouter.of(context);
        final messenger = context;
        if (widget.embedded) {
          widget.onClose?.call();
        } else if (router.canPop()) {
          router.pop();
        } else {
          router.go(Routes.chats);
        }
        // Delete after the screen has left, so it never flashes "not found".
        await Future<void>.delayed(
          Motion.sheet + const Duration(milliseconds: 100),
        );
        await notifier.delete(_id);
        if (messenger.mounted) showToast(messenger, 'Chat deleted');
    }
  }

  Future<void> _switchModel({required bool retry}) async {
    final before = ref.read(selectedModelIdProvider);
    final picked = await showModelPicker(context);
    if (!mounted || picked == null) return;
    final name = ref
        .read(modelCatalogProvider)
        .firstWhere((m) => m.id == picked)
        .name;
    if (picked != before) showToast(context, 'Switched to $name');
    // Auto-resend the reply that was waiting.
    if (ref.read(chatControllerProvider(_id)).error != null) {
      _ctl.retry(animate: _animate);
    }
  }

  void _tryAgain() {
    final m = ref.read(selectedModelProvider);
    final status = ref.read(modelStatusProvider(m.id));
    final err = ref.read(chatControllerProvider(_id)).error;
    if (err is ModelUnavailableError && !status.available) {
      showToast(
        context,
        '${m.name} is still unavailable. Try switching models.',
      );
      return;
    }
    _ctl.retry(animate: _animate);
  }

  // ── build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final conv = ref.watch(conversationProvider(_id));
    final ui = ref.watch(chatControllerProvider(_id));

    ref.listen<Conversation?>(conversationProvider(_id), _onConversation);
    // Switching model somewhere else (AI settings) resumes the waiting reply.
    ref.listen<String>(selectedModelIdProvider, (prev, next) {
      final err = ref.read(chatControllerProvider(_id)).error;
      if (prev != next &&
          err is ModelUnavailableError &&
          ref.read(modelStatusProvider(next)).available) {
        _ctl.retry(animate: _animate);
      }
    });
    ref.listen<ChatUiState>(chatControllerProvider(_id), (prev, next) {
      // A reply is starting while the reader is away: freeze what they see
      // right now, before anything below changes.
      if (prev != null && !prev.busy && next.busy) _freezeIfAway(next.activeId);
      // Announce a finished reply once, not chunk by chunk.
      if (prev != null && prev.busy && !next.busy && next.error == null) {
        SemanticsService.sendAnnouncement(
          View.of(context),
          'Reply finished',
          Directionality.of(context),
        );
      }
    });

    if (conv == null) {
      final loading = ref.watch(conversationsProvider).isLoading;
      return Scaffold(
        appBar: AppBar(),
        body: loading
            ? const SkeletonRows()
            : EmptyState(
                title: 'This chat isn’t here any more',
                primaryLabel: 'Back to chats',
                onPrimary: () => context.go(Routes.chats),
              ),
      );
    }

    final ch = ref.watch(characterProvider(conv.characterId)).valueOrNull;
    if (ch == null) {
      return Scaffold(appBar: AppBar(), body: const SkeletonRows());
    }

    final prefs = ref.watch(readingPrefsProvider);
    final mode = conv.mode;
    final story = mode == ChatMode.story;
    final messages = _display(conv.messages);
    final entries = story
        ? _storyEntries(conv, ch, messages, ui, prefs)
        : _chatEntries(ch, messages, ui, prefs);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            story
                ? _StoryHeader(
                    name: ch.first,
                    onBack: widget.embedded ? null : _back,
                    onOptions: () => _conversationOptions(conv, ch),
                    onReading: () => showReadingSheet(context, mode),
                    onChat: () => _switchMode(ChatMode.chat),
                  )
                : _ChatHeader(
                    character: ch,
                    onBack: widget.embedded ? null : _back,
                    onProfile: () => context.push(Routes.character(ch.id)),
                    onStory: () => _switchMode(ChatMode.story),
                    onOptions: () => _conversationOptions(conv, ch),
                  ),
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: MessageList(
                      key: story ? _storyListKey : _chatListKey,
                      entries: entries,
                      reversed: !story,
                      initialAnchor: _pendingAnchor,
                      maxContentWidth: story ? Reading.storyMaxWidth : null,
                      padding: EdgeInsets.symmetric(
                        horizontal: story ? Space.gutter + Space.xs : Space.lg,
                      ),
                      onNearBottomChanged: _onNearBottom,
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: Space.md,
                    child: Center(
                      child: JumpToLatestPill(
                        visible: _unseen,
                        onTap: () => _list(mode)?.scrollToBottom(animate: true),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            ChatToolsRow(
              conversationId: _id,
              onPick: (text) {
                _composer.text = text;
                _composer.selection = TextSelection.collapsed(offset: text.length);
                _focus.requestFocus();
              },
            ),
            ToastInset(
              child: Composer(
                controller: _composer,
                focusNode: _focus,
                variant: story ? ComposerVariant.story : ComposerVariant.chat,
                hintText: story ? null : 'Message ${ch.first}…',
                isGenerating: ui.busy,
                onSend: (t) => _send(t, mode),
                onStop: _stop,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(Routes.chats);
    }
  }

  // ── entries ───────────────────────────────────────────────────────────

  Widget? _noticeFor(ChatError? e) {
    if (e == null) return null;
    if (e is ModelUnavailableError) {
      final model = ref
          .read(modelCatalogProvider)
          .firstWhere((m) => m.id == e.modelId);
      return InlineNotice(
        title: model.busy
            ? '${model.name} is busy right now'
            : '${model.name} has used today’s free replies',
        message:
            'Your message is saved. Switch to another model to keep going, '
            'or come back after $resetsAtLabel when free replies reset.',
        primaryLabel: 'Switch model',
        onPrimary: () => _switchModel(retry: true),
        secondaryLabel: 'Try again',
        onSecondary: _tryAgain,
      );
    }
    if (e is ReplyFailedError) {
      return InlineNotice(
        title: 'The reply didn’t come through',
        message: 'Your message is saved. ${e.message}',
        primaryLabel: 'Try again',
        onPrimary: _tryAgain,
      );
    }
    return InlineNotice(
      title: 'Can’t reach Hearth right now',
      message: 'Your message is saved. Check your connection and try again.',
      primaryLabel: 'Try again',
      onPrimary: _tryAgain,
      icon: Icons.cloud_off_outlined,
    );
  }

  ListEntry? _noticeEntry(ChatUiState ui) {
    if (_freeze != null) return null;
    final n = _noticeFor(ui.error);
    if (n == null) return null;
    return ListEntry(
      id: '__notice',
      isMessage: false,
      builder: (_) => Padding(
        padding: const EdgeInsets.symmetric(vertical: Space.md),
        child: n,
      ),
    );
  }

  /// The quiet line (Chat) or ornament (Story) when this message shifted the
  /// relationship. Tapping opens the journal at that moment. With notes Hidden
  /// in the journal the line is gone; the journal still records everything.
  Widget? _noteFor(Message m, String characterId, {required bool story}) {
    final note = m.note;
    if (note == null || _hideNotes) return null;
    void open() =>
        context.push(Routes.relationship(characterId, entry: note.entryId));
    if (story) return RelationshipOrnament(note: note, onOpen: open);
    return RelationshipNoteLine(note: note, onOpen: open, alignEnd: m.isUser);
  }

  Widget _actionsFor(Message m, {required bool latest, required bool story}) {
    final ctl = _ctl;
    if (latest) {
      return Padding(
        padding: const EdgeInsets.only(top: Space.xs),
        child: MessageActions(
          altIndex: m.altIndex,
          altCount: m.alts.length,
          onPrevAlt: () => ctl.setAlt(m.id, m.altIndex - 1),
          onNextAlt: () => ctl.setAlt(m.id, m.altIndex + 1),
          onRewrite: () => ctl.rewrite(m.id, animate: _animate),
          onCopy: () => _copy(m),
          onEdit: () => setState(() => _editingId = m.id),
          rewriteLabel: story ? 'Rewrite passage' : 'Rewrite',
        ),
      );
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: IconButton(
        tooltip: 'More options for this message',
        icon: const Icon(Icons.more_horiz),
        onPressed: () => _messageOptions(m, latestAi: false),
        style: IconButton.styleFrom(minimumSize: const Size.square(Hit.inline)),
      ),
    );
  }

  List<ListEntry> _chatEntries(
    Character ch,
    List<Message> msgs,
    ChatUiState ui,
    ReadingPrefs prefs,
  ) {
    _hideNotes = ref.watch(
      appPrefsProvider.select(
        (p) => p.relationshipNotes == RelationshipNotes.hidden,
      ),
    );
    final style = context.ht.chatStyle(
      size: prefs.chatSize,
      lineHeight: prefs.chatLineHeight,
    );
    final out = <ListEntry>[];
    for (var i = 0; i < msgs.length; i++) {
      final m = msgs[i];
      final isLast = i == msgs.length - 1;
      out.add(
        ListEntry(
          id: m.id,
          builder: (ctx) {
            if (m.isUser) {
              if (_editingId == m.id) {
                return InlineEditor(
                  initial: m.text,
                  style: style,
                  onSave: (t) => _saveEdit(m, t),
                  onCancel: () => setState(() => _editingId = null),
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  UserBubble(
                    text: m.text,
                    style: style,
                    onMore: () => _messageOptions(m, latestAi: false),
                  ),
                  ?_noteFor(m, ch.id, story: false),
                ],
              );
            }
            // While frozen the message looks exactly as the reader last saw it.
            final frozenHere = _freeze?.activeId == m.id;
            final active = ui.activeId == m.id && !frozenHere;
            final thinking =
                m.text.isEmpty &&
                (frozenHere || (active && ui.status == GenStatus.thinking));
            final editing = _editingId == m.id;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: Space.md),
              child: Semantics(
                customSemanticsActions: {
                  const CustomSemanticsAction(label: 'Copy'): () => _copy(m),
                  if (!ui.busy)
                    const CustomSemanticsAction(label: 'Edit'): () =>
                        setState(() => _editingId = m.id),
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (thinking)
                      ThinkingIndicator(label: '${ch.first} is writing…')
                    else if (editing)
                      InlineEditor(
                        initial: m.text,
                        style: style,
                        onSave: (t) => _saveEdit(m, t),
                        onCancel: () => setState(() => _editingId = null),
                      )
                    else
                      GestureDetector(
                        onLongPress: active
                            ? null
                            : () => _messageOptions(m, latestAi: isLast),
                        child: RichRoleplayText(
                          m.text,
                          style: style,
                          streaming: active && ui.status == GenStatus.streaming,
                        ),
                      ),
                    if (ui.stoppedIds.contains(m.id) && !active)
                      const StoppedCaption(),
                    if (!active && !editing) ?_noteFor(m, ch.id, story: false),
                    if (!active && !editing && m.text.isNotEmpty)
                      _actionsFor(m, latest: isLast, story: false),
                  ],
                ),
              ),
            );
          },
        ),
      );
    }
    final notice = _noticeEntry(ui);
    if (notice != null) out.add(notice);
    return out;
  }

  List<ListEntry> _storyEntries(
    Conversation conv,
    Character ch,
    List<Message> msgs,
    ChatUiState ui,
    ReadingPrefs prefs,
  ) {
    final style = context.ht.storyStyle(
      size: prefs.storySize,
      lineHeight: prefs.storyLineHeight,
    );
    final userStyle = context.ht.storyStyle(
      size: (prefs.storySize - 2).clamp(
        Reading.storySize.min,
        Reading.storySize.max,
      ),
      lineHeight: 1.6,
    );
    _hideNotes = ref.watch(
      appPrefsProvider.select(
        (p) => p.relationshipNotes == RelationshipNotes.hidden,
      ),
    );
    final universe = ref.watch(universesProvider).valueOrNull;
    String? uniName;
    if (ch.universeId != null && universe != null) {
      for (final u in universe) {
        if (u.id == ch.universeId) uniName = u.name;
      }
    }

    final out = <ListEntry>[
      ListEntry(
        id: '__scene',
        isMessage: false,
        builder: (ctx) => Padding(
          padding: const EdgeInsets.only(bottom: Space.xl),
          child: Container(
            padding: const EdgeInsets.only(bottom: Space.xl),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: ctx.hc.outline)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(uniName ?? 'Standalone story', style: ctx.ht.caption),
                const SizedBox(height: Space.xs),
                Text(conv.title, style: ctx.ht.display),
              ],
            ),
          ),
        ),
      ),
    ];

    for (var i = 0; i < msgs.length; i++) {
      final m = msgs[i];
      final isLast = i == msgs.length - 1;
      out.add(
        ListEntry(
          id: m.id,
          builder: (ctx) {
            if (m.isUser) {
              if (_editingId == m.id) {
                return InlineEditor(
                  initial: m.text,
                  style: userStyle,
                  onSave: (t) => _saveEdit(m, t),
                  onCancel: () => setState(() => _editingId = null),
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  StoryYouBlock(
                    text: m.text,
                    style: userStyle,
                    onMore: () => _messageOptions(m, latestAi: false),
                  ),
                  ?_noteFor(m, ch.id, story: true),
                ],
              );
            }
            final active = ui.activeId == m.id;
            final thinking =
                active && ui.status == GenStatus.thinking && m.text.isEmpty;
            final editing = _editingId == m.id;
            return Padding(
              padding: const EdgeInsets.only(bottom: Space.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (thinking)
                    const ThinkingIndicator(
                      label: 'The story continues…',
                      story: true,
                    )
                  else if (editing)
                    InlineEditor(
                      initial: m.text,
                      style: style,
                      onSave: (t) => _saveEdit(m, t),
                      onCancel: () => setState(() => _editingId = null),
                    )
                  else
                    GestureDetector(
                      onLongPress: active
                          ? null
                          : () => _messageOptions(m, latestAi: isLast),
                      child: RichRoleplayText(
                        m.text,
                        style: style,
                        paragraphSpacing: prefs.storySize,
                        streaming: active && ui.status == GenStatus.streaming,
                      ),
                    ),
                  if (ui.stoppedIds.contains(m.id) && !active)
                    const StoppedCaption(),
                  if (!active && !editing) ?_noteFor(m, ch.id, story: true),
                  if (!active && !editing && m.text.isNotEmpty)
                    _actionsFor(m, latest: isLast, story: true),
                ],
              ),
            );
          },
        ),
      );
    }
    final notice = _noticeEntry(ui);
    if (notice != null) out.add(notice);
    return out;
  }
}

// ── headers ──────────────────────────────────────────────────────────────

bool _largeText(BuildContext context) =>
    MediaQuery.textScalerOf(context).scale(1) > 1.3;

class _ChatHeader extends StatelessWidget {
  const _ChatHeader({
    required this.character,
    required this.onBack,
    required this.onProfile,
    required this.onStory,
    required this.onOptions,
  });

  final Character character;
  final VoidCallback? onBack;
  final VoidCallback onProfile;
  final VoidCallback onStory;
  final VoidCallback onOptions;

  @override
  Widget build(BuildContext context) {
    final c = context.hc;
    final compact = _largeText(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Space.xs,
        Space.xs,
        Space.xs,
        Space.xs,
      ),
      child: Row(
        children: [
          if (onBack != null)
            IconButton(
              tooltip: 'Back',
              icon: const Icon(Icons.arrow_back),
              onPressed: onBack,
            )
          else
            const SizedBox(width: Space.sm),
          Expanded(
            child: Semantics(
              button: true,
              label: 'Open ${character.first}’s profile',
              excludeSemantics: true,
              onTap: onProfile,
              child: InkWell(
                borderRadius: BorderRadius.circular(Radii.button),
                onTap: onProfile,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: Hit.primary),
                  child: Row(
                    children: [
                      if (!compact) ...[
                        CharacterAvatar.of(
                          character,
                          size: Sizes.avatar - Space.sm,
                        ),
                        const SizedBox(width: Space.md),
                      ],
                      Expanded(
                        child: Text(
                          character.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: context.ht.title,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: Space.xs),
          if (compact)
            IconButton(
              tooltip: 'Switch to Story mode',
              icon: const Icon(Icons.auto_stories_outlined),
              onPressed: onStory,
            )
          else
            OutlinedButton.icon(
              onPressed: onStory,
              icon: const Icon(
                Icons.auto_stories_outlined,
                size: Space.xl - Space.xs,
              ),
              label: const Text('Story'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(Hit.primary, Hit.inline),
                foregroundColor: c.text,
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(horizontal: Space.lg),
              ),
            ),
          IconButton(
            tooltip: 'Conversation options',
            icon: const Icon(Icons.more_horiz),
            onPressed: onOptions,
          ),
        ],
      ),
    );
  }
}

class _StoryHeader extends StatelessWidget {
  const _StoryHeader({
    required this.name,
    required this.onBack,
    required this.onOptions,
    required this.onReading,
    required this.onChat,
  });

  final String name;
  final VoidCallback? onBack;
  final VoidCallback onOptions;
  final VoidCallback onReading;
  final VoidCallback onChat;

  @override
  Widget build(BuildContext context) {
    final c = context.hc;
    final compact = _largeText(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Space.xs,
        Space.xs,
        Space.xs,
        Space.xs,
      ),
      child: Row(
        children: [
          if (onBack != null)
            IconButton(
              tooltip: 'Back',
              icon: const Icon(Icons.arrow_back),
              onPressed: onBack,
            )
          else
            const SizedBox(width: Space.sm),
          Expanded(
            child: Semantics(
              button: true,
              label: 'Story options',
              excludeSemantics: true,
              onTap: onOptions,
              child: InkWell(
                borderRadius: BorderRadius.circular(Radii.button),
                onTap: onOptions,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: Hit.primary),
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          '$name · Story'.toUpperCase(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: context.ht.overline,
                        ),
                      ),
                      const SizedBox(width: Space.xs),
                      Icon(
                        Icons.keyboard_arrow_down,
                        size: Space.lg + Space.xs,
                        color: c.textSubtle,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Reading and writing preferences',
            onPressed: onReading,
            icon: Text(
              'Aa',
              textScaler: TextScaler.noScaling,
              style: context.ht.title.copyWith(
                color: c.text,
                fontSize: Space.xl - Space.xs,
              ),
            ),
          ),
          if (compact)
            IconButton(
              tooltip: 'Switch to Chat mode',
              icon: const Icon(Icons.chat_bubble_outline),
              onPressed: onChat,
            )
          else
            OutlinedButton.icon(
              onPressed: onChat,
              icon: const Icon(
                Icons.chat_bubble_outline,
                size: Space.xl - Space.xs,
              ),
              label: const Text('Chat'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(Hit.primary, Hit.inline),
                foregroundColor: c.text,
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(horizontal: Space.lg),
              ),
            ),
        ],
      ),
    );
  }
}
