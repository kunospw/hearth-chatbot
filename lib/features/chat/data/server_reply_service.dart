import 'dart:async';

import '../../../core/backend/backend_api.dart';
import '../../../core/backend/mappers.dart';
import '../../../data/mock/mock_scenario.dart';
import '../../relationship/data/relationship_json.dart';
import '../../relationship/domain/relationship_models.dart';
import 'reply_streaming_service.dart';

/// Replies from the server's `chat_turn` function (which calls the model; the
/// model key never reaches this device). The server loads the conversation
/// itself, judges your message, builds the prompt with the relationship block
/// and validates the one event the model may propose, so this only sends ids
/// and your preferences.
class ServerReplyStreamingService implements ReplyStreamingService {
  ServerReplyStreamingService(this.api);

  final BackendApi api;

  @override
  bool get handlesRelationship => true;

  /// The server decides what to do about a proposal; there is nothing to propose from here.
  @override
  Future<RelationshipProposalDraft?> relationshipProposal(
    ReplyRequest request,
    String finalText,
  ) async => null;

  /// A controller (not an `async*` generator) so that cancelling closes the
  /// connection at once: a generator would only notice at its next `yield`,
  /// which can be seconds away while the model is still thinking.
  @override
  Stream<String> streamReply(ReplyRequest r) {
    final conversationId = r.conversationId;
    final personaId = r.personaId;
    final aiMessageId = r.aiMessageId;
    if (conversationId == null || personaId == null || aiMessageId == null) {
      return Stream.error(
        StateError(
          'A server reply needs the conversation, persona and reply ids.',
        ),
      );
    }
    final body = <String, Object?>{
      'conversationId': conversationId,
      'personaId': personaId,
      'modelId': r.modelId,
      'aiMessageId': aiMessageId,
      'altIndex': r.altIndex,
      'settings': r.settings.toJson(),
      'userMessageId': ?r.userMessageId,
      'replaceMessageId': ?r.replaceMessageId,
    };

    StreamSubscription<SseEvent>? sub;
    late final StreamController<String> out;
    var text = '';
    var finished = false;

    void fail(Object e) {
      if (out.isClosed) return;
      if (e is OfflineBackendException) {
        out.addError(const OfflineException());
      } else if (e is BackendException) {
        // Before the reply started: the answer can still carry what your message did.
        final note = _note(e.body['userNote']);
        final rel = _relationship(e.body['relationship']);
        if (note != null || rel != null) {
          r.onServerInfo?.call(
            ServerTurnInfo(userNote: note, relationship: rel),
          );
        }
        out.addError(ReplyException(e.code, e.message));
      } else {
        out.addError(e);
      }
      out.close();
    }

    void handle(SseEvent e) {
      switch (e.event) {
        case 'start':
          r.onServerInfo?.call(_start(e.data, r.modelId));
        case 'delta':
          text += (e.data['text'] as String?) ?? '';
          // With animations off the reply arrives all at once, at the end.
          if (r.stream) out.add(text);
        case 'done':
          final finalText = (e.data['text'] as String?) ?? text;
          if (finalText != text || !r.stream) out.add(finalText);
          r.onServerInfo?.call(
            ServerTurnInfo(
              replyNote: _note(e.data['note']),
              relationship: _relationship(e.data['relationship']),
              done: true,
            ),
          );
          finished = true;
        case 'error':
          sub?.cancel();
          fail(
            ReplyException(
              (e.data['code'] as String?) ?? 'server_error',
              (e.data['message'] as String?) ?? 'Something went wrong.',
            ),
          );
      }
    }

    // A reply the app cannot read is an error the person sees, never a reply
    // that hangs on "writing…".
    void onEvent(SseEvent e) {
      try {
        handle(e);
      } catch (_) {
        sub?.cancel();
        fail(
          const ReplyException(
            'server_error',
            'The reply came back in a form we couldn’t read. Try again.',
          ),
        );
      }
    }

    out = StreamController<String>(
      onListen: () {
        sub = api
            .stream('chat_turn', body)
            .listen(
              onEvent,
              onError: fail,
              onDone: () {
                if (out.isClosed) return;
                // The connection closed without a final word: a dropped connection.
                if (!finished) {
                  out.addError(const OfflineException());
                }
                out.close();
              },
              cancelOnError: true,
            );
      },
      // Stopping closes the connection to the server straight away. Not awaited:
      // with `cancelOnError` a listener only hears an error after this returns,
      // so a slow (or already finished) cancel must never hold it up.
      onCancel: () {
        unawaited(sub?.cancel());
      },
    );
    return out.stream;
  }

  static ServerTurnInfo _start(Map<String, dynamic> d, String modelId) {
    final usage = d['usage'];
    int? left;
    if (usage is Map && usage['limit'] != null && usage['used'] != null) {
      left = ((usage['limit'] as num) - (usage['used'] as num)).toInt();
    }
    return ServerTurnInfo(
      userNote: _note(d['userNote']),
      relationship: _relationship(d['relationship']),
      freeRepliesLeft: left,
      modelId: modelId,
    );
  }

  static RelationshipNote? _note(Object? j) =>
      j is Map ? noteFromJson(Map<String, dynamic>.from(j)) : null;

  static Relationship? _relationship(Object? j) =>
      j is Map ? relationshipFromJson(Map<String, dynamic>.from(j)) : null;
}
