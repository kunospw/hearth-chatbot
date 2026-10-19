import 'dart:async';
import 'dart:convert';

import '../../../core/backend/backend_api.dart';
import '../../../core/backend/mappers.dart';
import '../domain/chat_models.dart';
import 'conversation_repository.dart';

/// Conversations and their messages stored in your account.
///
/// The chat edits a conversation many times a second while a reply streams, so
/// [save] only remembers the latest version and writes it after things go
/// quiet (or at once on [flush], which the chat calls before it asks the
/// server to reply, so the server always sees the messages you just sent). Only
/// what changed is sent.
class SupabaseConversationRepository implements ConversationRepository {
  SupabaseConversationRepository(
    this.api, {
    this.quiet = const Duration(milliseconds: 700),
  });

  final BackendApi api;
  final Duration quiet;

  /// What the database has, as JSON per row (to send only differences).
  final Map<String, _Saved> _saved = {};
  final Map<String, Conversation> _pending = {};
  final Map<String, Timer> _timers = {};
  final Map<String, Future<void>> _writes = {};

  String get _uid =>
      api.userId ??
      (throw const BackendException(401, 'unauthorized', 'Sign in first.'));

  // ── reading ───────────────────────────────────────────────────────────

  @override
  Future<List<Conversation>> list() async {
    final convs = await api.select(
      'conversations',
      orderBy: 'updated_at',
      ascending: false,
    );
    final msgs = await api.select('messages', orderBy: 'seq');
    final byConv = <String, List<Message>>{};
    for (final m in msgs) {
      byConv
          .putIfAbsent(m['conversation_id'] as String, () => [])
          .add(messageFromRow(m));
    }
    final out = <Conversation>[];
    for (final r in convs) {
      final c = conversationFromRow(r, byConv[r['id']] ?? const []);
      _remember(c);
      out.add(c);
    }
    return out;
  }

  @override
  Future<Conversation?> byId(String id) async {
    final rows = await api.select('conversations', eq: {'id': id}, limit: 1);
    if (rows.isEmpty) return null;
    final msgs = await api.select(
      'messages',
      eq: {'conversation_id': id},
      orderBy: 'seq',
    );
    final c = conversationFromRow(rows.first, [
      for (final m in msgs) messageFromRow(m),
    ]);
    _remember(c);
    return c;
  }

  // ── writing ───────────────────────────────────────────────────────────

  @override
  Future<void> save(Conversation conversation) async {
    _pending[conversation.id] = conversation;
    _timers[conversation.id]?.cancel();
    _timers[conversation.id] = Timer(
      quiet,
      () => unawaited(flush(conversation.id).catchError((Object _) {})),
    );
  }

  @override
  Future<void> flush(String id) {
    _timers.remove(id)?.cancel();
    // Writes for one conversation never overlap.
    final previous = _writes[id] ?? Future<void>.value();
    final next = previous.then((_) => _write(id));
    _writes[id] = next.catchError((Object _) {});
    return next;
  }

  Future<void> _write(String id) async {
    final c = _pending.remove(id);
    if (c == null) return;
    final uid = _uid;
    final before = _saved[id];
    try {
      final convRow = conversationToRow(c, userId: uid);
      final convJson = jsonEncode(convRow);
      if (before == null || before.conv != convJson) {
        await api.upsert('conversations', convRow);
      }
      final rows = <Map<String, Object?>>[];
      final json = <String, String>{};
      for (final m in c.messages) {
        final row = messageToRow(m, conversationId: id, userId: uid);
        final j = jsonEncode(row);
        json[m.id] = j;
        if (before?.messages[m.id] != j) rows.add(row);
      }
      if (rows.isNotEmpty) await api.upsert('messages', rows);
      for (final gone in (before?.messages.keys ?? const <String>[])) {
        if (!json.containsKey(gone)) {
          await api.delete('messages', eq: {'id': gone});
        }
      }
      _saved[id] = _Saved(convJson, json);
    } catch (e) {
      // Offline or a hiccup: keep the latest version and try again shortly.
      _pending.putIfAbsent(id, () => c);
      _timers[id]?.cancel();
      _timers[id] = Timer(
        const Duration(seconds: 5),
        () => unawaited(flush(id).catchError((Object _) {})),
      );
      rethrow;
    }
  }

  @override
  Future<void> delete(String id) async {
    _timers.remove(id)?.cancel();
    _pending.remove(id);
    await (_writes[id] ?? Future<void>.value());
    await api.delete('conversations', eq: {'id': id});
    _saved.remove(id);
  }

  void _remember(Conversation c) {
    final uid = api.userId;
    if (uid == null) return;
    _saved[c.id] = _Saved(jsonEncode(conversationToRow(c, userId: uid)), {
      for (final m in c.messages)
        m.id: jsonEncode(messageToRow(m, conversationId: c.id, userId: uid)),
    });
  }
}

class _Saved {
  const _Saved(this.conv, this.messages);

  final String conv;
  final Map<String, String> messages;
}
