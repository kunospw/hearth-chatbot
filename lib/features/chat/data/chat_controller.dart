import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/util/throttler.dart';
import '../../characters/data/character_repository.dart';
import '../../characters/domain/character.dart';
import '../../relationship/data/relationship_providers.dart';
import '../../relationship/domain/relationship_bands.dart';
import '../../relationship/domain/relationship_models.dart';
import '../../library/data/library_repository.dart';
import '../../settings/data/ai_prefs.dart';
import '../../settings/data/model_usage.dart';
import '../domain/chat_models.dart';
import 'conversation_repository.dart';
import 'reply_streaming_service.dart';

enum GenStatus { idle, thinking, streaming }

/// Why the last reply couldn't be produced. The user's message is always kept.
@immutable
sealed class ChatError {
  const ChatError(this.regenId);

  /// Set when the failed attempt was a Rewrite of this message.
  final String? regenId;
}

/// The chosen model is out of free replies or busy.
class ModelUnavailableError extends ChatError {
  const ModelUnavailableError(this.modelId, super.regenId);
  final String modelId;
}

class OfflineChatError extends ChatError {
  const OfflineChatError(super.regenId);
}

/// The server answered but could not write the reply (the model had a problem).
class ReplyFailedError extends ChatError {
  const ReplyFailedError(this.message, super.regenId);
  final String message;
}

enum StopResult { none, kept, removed }

@immutable
class ChatUiState {
  const ChatUiState({
    this.status = GenStatus.idle,
    this.activeId,
    this.stoppedIds = const {},
    this.error,
  });

  final GenStatus status;

  /// The message currently being written (a new reply, or the one being rewritten).
  final String? activeId;

  /// Messages whose last reply was stopped early (shown with "Stopped").
  final Set<String> stoppedIds;
  final ChatError? error;

  bool get busy => status != GenStatus.idle;

  ChatUiState copyWith({
    GenStatus? status,
    String? activeId,
    bool clearActive = false,
    Set<String>? stoppedIds,
    ChatError? error,
    bool clearError = false,
  }) => ChatUiState(
    status: status ?? this.status,
    activeId: clearActive ? null : (activeId ?? this.activeId),
    stoppedIds: stoppedIds ?? this.stoppedIds,
    error: clearError ? null : (error ?? this.error),
  );
}

const _uuid = Uuid();

/// Drives one conversation: sending, streaming, stopping, rewriting, editing
/// and the model-limit / offline error flow. Messages live in
/// [ConversationsNotifier]; this holds only the transient generation state.
/// Rebuilds of the message list are throttled to ~60ms while streaming.
class ChatController extends FamilyNotifier<ChatUiState, String> {
  static const throttle = Duration(milliseconds: 60);

  StreamSubscription<String>? _sub;
  final _throttler = Throttler(throttle);
  String _buffer = '';
  String? _regenId;
  String? _chargedModel;
  bool _starting = false;

  /// The message of yours the next reply answers (the server judges it and may
  /// need it again on a retry; it counts once either way).
  String? _userMessageId;
  String? _replyModelId;

  @override
  ChatUiState build(String arg) {
    ref.onDispose(() {
      _sub?.cancel();
      _throttler.cancel();
    });
    return const ChatUiState();
  }

  ConversationsNotifier get _convs => ref.read(conversationsProvider.notifier);

  /// With a server, the server judges messages and proposals inside the reply.
  bool get _server =>
      ref.read(replyStreamingServiceProvider).handlesRelationship;
  Conversation? get _conv => ref.read(conversationProvider(arg));

  // ── sending ───────────────────────────────────────────────────────────

  /// Adds the user's message and asks for a reply. No-op while one is being written.
  Future<void> send(String text, {bool animate = true}) async {
    final t = text.trim();
    if (t.isEmpty || state.busy || _starting) return;
    final msg = Message(id: _uuid.v4(), role: MessageRole.user, alts: [t]);
    _convs.change(
      arg,
      (c) =>
          c.copyWith(messages: [...c.messages, msg], updatedAt: DateTime.now()),
    );
    _userMessageId = msg.id;
    // The backend decides whether this message moved the relationship. (With a
    // server that happens inside the reply request, below.)
    final conv = _conv;
    if (conv != null && !_server) {
      final note = await ref
          .read(relationshipsProvider.notifier)
          .onUserMessage(
            characterId: conv.characterId,
            messageId: msg.id,
            text: t,
            conversationId: arg,
            chatTitle: conv.title,
          );
      if (note != null) _setNote(msg.id, 0, note);
    }
    await _generate(animate: animate);
  }

  void _setNote(String messageId, int altIndex, RelationshipNote? note) {
    _convs.change(
      arg,
      (c) => c.copyWith(
        messages: [
          for (final m in c.messages)
            if (m.id == messageId)
              m.copyWith(
                notes: {
                  for (final e in m.notes.entries)
                    if (e.key != altIndex) e.key: e.value,
                  altIndex: ?note,
                },
              )
            else
              m,
        ],
      ),
    );
  }

  /// Story mode: send with nothing typed. The story continues.
  Future<void> continueStory({bool animate = true}) =>
      _generate(animate: animate);

  /// Writes another version of an AI message (adds an alt).
  Future<void> rewrite(String messageId, {bool animate = true}) =>
      _generate(regenId: messageId, animate: animate);

  /// Your last message never got a reply (it failed, or the app was closed):
  /// ask for one again. The server counts the message only once.
  Future<void> resend({bool animate = true}) async {
    final last = _conv?.messages.lastOrNull;
    if (last == null || !last.isUser || state.busy) return;
    state = state.copyWith(clearError: true);
    _userMessageId = last.id;
    await _generate(animate: animate);
  }

  /// After an error (or after switching model): try the waiting reply again.
  Future<void> retry({bool animate = true}) async {
    final e = state.error;
    if (e == null) return;
    state = state.copyWith(clearError: true);
    await _generate(regenId: e.regenId, animate: animate);
  }

  Future<void> _generate({String? regenId, bool animate = true}) async {
    if (state.busy || _starting) return;
    final conv = _conv;
    if (conv == null) return;

    final modelId = ref.read(selectedModelIdProvider);
    if (!ref.read(modelStatusProvider(modelId)).available) {
      state = state.copyWith(error: ModelUnavailableError(modelId, regenId));
      return;
    }

    _starting = true;
    try {
      final Character? character;
      try {
        character = await ref
            .read(characterRepositoryProvider)
            .byId(conv.characterId);
      } catch (_) {
        state = state.copyWith(error: OfflineChatError(regenId));
        return;
      }
      if (character == null) return;

      final server = _server;
      // With a server the saved messages are what it reads: make sure it has them.
      // (If they can't be saved we can't ask for a reply: say so, keep the message.)
      if (server) {
        try {
          await _convs.flush(arg);
        } catch (_) {
          state = state.copyWith(error: OfflineChatError(regenId));
          return;
        }
      }

      // The server counts free replies itself and tells us how many are left.
      if (!server) {
        ref.read(modelUsageProvider.notifier).consume(modelId);
        _chargedModel = modelId;
      }
      _regenId = regenId;
      _replyModelId = modelId;

      // A rewrite replaces the version on screen, so what the old version did
      // to the relationship is taken back (it counts again if you come back to it).
      if (regenId != null) {
        await _takeBackAltEffect(regenId, _messageById(regenId)?.altIndex ?? 0);
      }
      final Relationship relationship;
      try {
        relationship = await ref
            .read(relationshipsProvider.notifier)
            .ensure(conv.characterId);
      } catch (_) {
        state = state.copyWith(error: OfflineChatError(regenId));
        return;
      }

      // Mark generation as started *before* the placeholder appears, so the
      // screen never sees new content without knowing a reply is being written.
      final msgId = regenId ?? _uuid.v4();
      String? avoid;
      state = ChatUiState(
        status: GenStatus.thinking,
        activeId: msgId,
        stoppedIds: {...state.stoppedIds}..remove(msgId),
      );
      if (regenId != null) {
        _convs.change(
          arg,
          (c) => c.copyWith(
            messages: [
              for (final m in c.messages)
                if (m.id == regenId)
                  () {
                    avoid = m.text;
                    return m.copyWith(
                      alts: [...m.alts, ''],
                      altIndex: m.alts.length,
                    );
                  }()
                else
                  m,
            ],
            updatedAt: DateTime.now(),
          ),
        );
      } else {
        _convs.change(
          arg,
          (c) => c.copyWith(
            messages: [
              ...c.messages,
              Message(id: msgId, role: MessageRole.ai, alts: const ['']),
            ],
            updatedAt: DateTime.now(),
          ),
        );
      }

      final fresh = _conv!;
      final history = <Message>[];
      for (final m in fresh.messages) {
        if (m.id == msgId) break;
        history.add(m);
      }

      _buffer = '';
      final ai = ref.read(aiPrefsProvider);
      final request = ReplyRequest(
        character: character,
        history: history,
        modelId: modelId,
        avoidText: avoid,
        stream: animate,
        relationshipBlock: promptBlock(relationship),
        tier: replyTier(relationship),
        conversationId: arg,
        personaId: ref.read(activePersonaIdProvider),
        userMessageId: regenId == null ? _userMessageId : null,
        replaceMessageId: regenId,
        aiMessageId: msgId,
        altIndex: regenId == null ? 0 : (_messageById(msgId)?.altIndex ?? 0),
        settings: ReplySettings(
          length: ai.length.name,
          style: ai.style.name,
          temperature: ai.advanced.temperature,
          maxTokens: ai.advanced.maxTokens,
          repetitionPenalty: ai.advanced.repetitionPenalty,
          contextDepth: ai.advanced.contextDepth,
        ),
        onServerInfo: _onServerInfo,
      );
      _lastRequest = request;
      _sub = ref
          .read(replyStreamingServiceProvider)
          .streamReply(request)
          .listen(
            _onText,
            onError: _onError,
            onDone: _onDone,
            cancelOnError: true,
          );
    } finally {
      _starting = false;
    }
  }

  void _onText(String text) {
    _buffer = text;
    if (state.status == GenStatus.thinking) {
      state = state.copyWith(status: GenStatus.streaming);
    }
    _throttler.run(_flush);
  }

  void _flush() => _writeActive(_buffer);

  void _writeActive(String text) {
    final id = state.activeId;
    if (id == null) return;
    _convs.change(
      arg,
      (c) => c.copyWith(
        messages: [
          for (final m in c.messages)
            if (m.id == id)
              m.copyWith(
                alts: [
                  for (var i = 0; i < m.alts.length; i++)
                    i == m.altIndex ? text : m.alts[i],
                ],
              )
            else
              m,
        ],
      ),
    );
  }

  void _onDone() {
    _throttler.flush();
    _sub = null;
    final id = state.activeId;
    state = state.copyWith(status: GenStatus.idle, clearActive: true);
    _convs.change(arg, (c) => c.copyWith(updatedAt: DateTime.now()));
    _userMessageId = null;
    if (id != null) _afterReply(id);
  }

  ReplyRequest? _lastRequest;

  Message? _messageById(String id) {
    for (final m in _conv?.messages ?? const <Message>[]) {
      if (m.id == id) return m;
    }
    return null;
  }

  /// The model may propose ONE relationship event about its own reply. The
  /// backend validates it (kind, evidence, cooldowns, budgets…) and decides.
  Future<void> _afterReply(String messageId) async {
    if (_server) return; // the server already validated the model's proposal
    final req = _lastRequest;
    final m = _messageById(messageId);
    if (req == null || m == null || m.text.trim().isEmpty) return;
    final draft = await ref
        .read(replyStreamingServiceProvider)
        .relationshipProposal(req, m.text);
    if (draft == null) return;
    await _countProposal(
      m,
      m.altIndex,
      draft.kindId,
      draft.evidence,
      draft.reason,
    );
  }

  Future<void> _countProposal(
    Message m,
    int altIndex,
    String kindId,
    String evidence,
    String reason,
  ) async {
    final conv = _conv;
    final req = _lastRequest;
    if (conv == null) return;
    final recent = <String>[];
    for (final x in conv.messages) {
      if (x.id == m.id) break;
      recent.add(x.text);
    }
    recent.add(m.alts[altIndex.clamp(0, m.alts.length - 1)]);
    final note = await ref
        .read(relationshipsProvider.notifier)
        .onModelProposal(
          characterId: conv.characterId,
          messageId: m.id,
          kindId: kindId,
          evidence: evidence,
          reason: reason,
          recentMessages: recent,
          characterFirst: req?.character.first ?? 'They',
          conversationId: arg,
          chatTitle: conv.title,
        );
    // Keep the proposal on the note, so switching back to this version counts it again.
    _setNote(m.id, altIndex, note);
  }

  /// Reverses what the version at [altIndex] did to the relationship (if it did anything).
  Future<void> _takeBackAltEffect(String messageId, int altIndex) async {
    final m = _messageById(messageId);
    final conv = _conv;
    final note = m?.notes[altIndex];
    if (m == null || conv == null || note?.entryId == null) return;
    final rel = ref.read(relationshipProvider(conv.characterId)).valueOrNull;
    final active =
        rel?.events.any((e) => e.id == note!.entryId && !e.isUndone) ?? false;
    if (active) {
      await ref
          .read(relationshipsProvider.notifier)
          .undo(
            conv.characterId,
            note!.entryId!,
            reason: 'You switched to another version of the reply, so this no longer happened.',
          );
    }
  }

  void _onError(Object e, StackTrace _) {
    _throttler.cancel();
    _sub = null;
    final regen = _regenId;
    _removeActive();
    _refund();
    final ChatError error;
    if (e is ReplyException && e.isModelProblem) {
      final String model = _replyModelId ?? ref.read(selectedModelIdProvider);
      // A limit means none are left, whatever we thought.
      if (e.code == 'model_limit') {
        ref.read(modelUsageProvider.notifier).setLeft(model, 0);
      }
      error = ModelUnavailableError(model, regen);
    } else if (e is ReplyException) {
      error = ReplyFailedError(e.message, regen);
    } else {
      error = OfflineChatError(regen);
    }
    state = ChatUiState(stoppedIds: state.stoppedIds, error: error);
  }

  /// The server reports what it decided: what your message did to the
  /// relationship, how many free replies are left, and what the character's
  /// own action did.
  void _onServerInfo(ServerTurnInfo info) {
    final rel = info.relationship;
    if (rel != null) ref.read(relationshipsProvider.notifier).apply(rel);
    final userId = _userMessageId;
    if (info.userNote != null && userId != null) {
      _setNote(userId, 0, info.userNote);
    }
    final left = info.freeRepliesLeft;
    final model = info.modelId;
    if (left != null && model != null) {
      ref.read(modelUsageProvider.notifier).setLeft(model, left);
    }
    if (info.done) {
      final id = state.activeId;
      final m = id == null ? null : _messageById(id);
      if (m != null) _setNote(m.id, m.altIndex, info.replyNote);
    }
  }

  /// Removes the placeholder: the whole message for a new reply, or just the
  /// new alt for a rewrite.
  void _removeActive() {
    final id = state.activeId;
    if (id == null) return;
    _convs.change(arg, (c) {
      final out = <Message>[];
      for (final m in c.messages) {
        if (m.id != id) {
          out.add(m);
        } else if (_regenId != null && m.alts.length > 1) {
          final alts = m.alts.sublist(0, m.alts.length - 1);
          out.add(m.copyWith(alts: alts, altIndex: alts.length - 1));
        }
      }
      return c.copyWith(messages: out);
    });
  }

  void _refund() {
    final m = _chargedModel;
    if (m != null) ref.read(modelUsageProvider.notifier).refund(m);
    _chargedModel = null;
  }

  // ── stopping ──────────────────────────────────────────────────────────

  /// Stops writing. Partial text is kept (with "…"); if nothing had arrived
  /// yet the placeholder is removed and the free reply refunded.
  StopResult stop() {
    if (!state.busy) return StopResult.none;
    _sub?.cancel();
    _sub = null;
    _throttler.cancel();
    final id = state.activeId!;
    final partial = _buffer.trim();
    if (partial.isEmpty) {
      _removeActive();
      _refund();
      state = state.copyWith(status: GenStatus.idle, clearActive: true);
      return StopResult.removed;
    }
    _writeActive('$partial…');
    state = state.copyWith(
      status: GenStatus.idle,
      clearActive: true,
      stoppedIds: {...state.stoppedIds, id},
    );
    _convs.change(arg, (c) => c.copyWith(updatedAt: DateTime.now()));
    return StopResult.kept;
  }

  // ── editing and alts ──────────────────────────────────────────────────

  void setAlt(String messageId, int index) {
    final before = _messageById(messageId);
    final to = before == null ? index : index.clamp(0, before.alts.length - 1);
    _convs.change(
      arg,
      (c) => c.copyWith(
        messages: [
          for (final m in c.messages)
            if (m.id == messageId) m.copyWith(altIndex: to) else m,
        ],
      ),
    );
    if (before != null && before.altIndex != to) {
      _altSwitched(before, before.altIndex, to);
    }
  }

  /// A character-side event belongs to the version being shown: leaving a
  /// version takes it back, and coming back to one that proposed something
  /// counts it again (validated afresh).
  Future<void> _altSwitched(Message m, int from, int to) async {
    await _takeBackAltEffect(m.id, from);
    final conv = _conv;
    if (conv == null) return;
    if (_server) {
      // The server remembers what the model proposed for that version.
      final note = await ref
          .read(relationshipsProvider.notifier)
          .recountProposal(conv.characterId, m.id, to);
      _setNote(m.id, to, note);
      return;
    }
    final n = m.notes[to];
    if (n?.kindId == null || n?.evidence == null) return;
    await _countProposal(m, to, n!.kindId!, n.evidence!, n.reason ?? '');
  }

  /// Replaces the visible text of a message. Returns false if [text] is empty.
  bool edit(String messageId, String text) {
    final t = text.trim();
    if (t.isEmpty) return false;
    _convs.change(
      arg,
      (c) => c.copyWith(
        messages: [
          for (final m in c.messages)
            if (m.id == messageId)
              m.copyWith(
                alts: [
                  for (var i = 0; i < m.alts.length; i++)
                    i == m.altIndex ? t : m.alts[i],
                ],
              )
            else
              m,
        ],
      ),
    );
    if (state.stoppedIds.contains(messageId)) {
      state = state.copyWith(
        stoppedIds: {...state.stoppedIds}..remove(messageId),
      );
    }
    // An edited message of yours is judged again; its old effect is replaced.
    final m = _messageById(messageId);
    final conv = _conv;
    if (m != null && m.isUser && conv != null) {
      Future<RelationshipNote?> judge() => ref
          .read(relationshipsProvider.notifier)
          .onEditedMessage(
            characterId: conv.characterId,
            messageId: messageId,
            text: t,
            conversationId: arg,
            chatTitle: conv.title,
          );
      // The server reads the edited text from the saved message: save it first.
      final judged = _server ? _convs.flush(arg).then((_) => judge()) : judge();
      judged.then(
        (note) => _setNote(messageId, 0, note),
        onError: (Object _) {},
      );
    }
    return true;
  }

  void clearError() => state = state.copyWith(clearError: true);
}

final chatControllerProvider =
    NotifierProvider.family<ChatController, ChatUiState, String>(
      ChatController.new,
    );
