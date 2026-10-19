import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/backend/backend_providers.dart';
import '../../../data/mock/mock_data.dart';
import '../../../data/mock/mock_scenario.dart';
import '../../characters/domain/character.dart';
import '../../relationship/domain/relationship_models.dart';
import '../domain/chat_models.dart';
import 'server_reply_service.dart';

/// Everything the service needs to write the next reply.
class ReplyRequest {
  const ReplyRequest({
    required this.character,
    required this.history,
    required this.modelId,
    this.avoidText,
    this.stream = true,
    this.relationshipBlock,
    this.tier = 'guarded',
    this.conversationId,
    this.personaId,
    this.userMessageId,
    this.replaceMessageId,
    this.aiMessageId,
    this.altIndex = 0,
    this.settings = const ReplySettings(),
    this.onServerInfo,
  });

  final Character character;

  /// Messages before the reply being written, each as its visible version.
  final List<Message> history;
  final String modelId;

  /// The reply being replaced (on Rewrite); the service avoids repeating it.
  final String? avoidText;

  /// False when the user turned animations off: emit the whole reply at once.
  final bool stream;

  /// The relationship block the server adds to the prompt every turn (what the
  /// AI is told). The fake service ignores it; the real one sends it.
  final String? relationshipBlock;

  /// How openly the character replies (guarded / opening / warm), from the
  /// relationship. Only the fake service uses it.
  final String tier;

  // ── used by the server service only (it builds the prompt itself) ──

  final String? conversationId;
  final String? personaId;

  /// The message you just sent (already saved), if this reply answers one.
  final String? userMessageId;

  /// A Rewrite: the reply being replaced.
  final String? replaceMessageId;

  /// The id of the reply being written, and which version of it this is.
  final String? aiMessageId;
  final int altIndex;
  final ReplySettings settings;

  /// The server tells the app what it decided about the relationship, and how
  /// many free replies are left, while the reply is written.
  final void Function(ServerTurnInfo info)? onServerInfo;
}

/// Your AI settings, as the server needs them.
class ReplySettings {
  const ReplySettings({
    this.length = 'medium',
    this.style = 'descriptive',
    this.temperature = 0.9,
    this.maxTokens = 600,
    this.repetitionPenalty = 1.1,
    this.contextDepth = 40,
  });

  final String length;
  final String style;
  final double temperature;
  final int maxTokens;
  final double repetitionPenalty;
  final int contextDepth;

  Map<String, Object> toJson() => {
    'length': length,
    'style': style,
    'temperature': temperature,
    'maxTokens': maxTokens,
    'repetitionPenalty': repetitionPenalty,
    'contextDepth': contextDepth,
  };
}

/// What the server reports about a turn: before the reply (what your message
/// did) and after it (what the character's own action did).
class ServerTurnInfo {
  const ServerTurnInfo({
    this.userNote,
    this.replyNote,
    this.relationship,
    this.freeRepliesLeft,
    this.modelId,
    this.done = false,
  });

  final RelationshipNote? userNote;
  final RelationshipNote? replyNote;
  final Relationship? relationship;

  /// Free replies left today on [modelId] (null = no daily limit).
  final int? freeRepliesLeft;
  final String? modelId;

  /// True for the report at the end of the reply.
  final bool done;
}

/// The server could not produce the reply. [code] is a short word
/// (`model_limit`, `model_busy`, `model_unavailable`, `empty_reply`, …).
class ReplyException implements Exception {
  const ReplyException(this.code, this.message);

  final String code;
  final String message;

  bool get isModelProblem =>
      code == 'model_limit' ||
      code == 'model_busy' ||
      code == 'model_unavailable' ||
      code == 'unknown_model';

  @override
  String toString() => 'ReplyException($code, $message)';
}

/// What the model proposed in its reply: one relationship event with a quote as
/// evidence. The app never trusts it; the backend validates it.
class RelationshipProposalDraft {
  const RelationshipProposalDraft({
    required this.kindId,
    required this.evidence,
    required this.reason,
  });
  final String kindId;
  final String evidence;
  final String reason;
}

/// Source of AI replies. The production implementation calls the server
/// (Phase 6); the fake below streams canned replies.
///
/// Emits the reply so far (cumulative text), so a listener can simply replace
/// what it shows. Errors: [OfflineException].
abstract interface class ReplyStreamingService {
  /// True when the server also judges your message and the character's own
  /// action while the reply is written (the app then makes no relationship
  /// calls of its own for a turn).
  bool get handlesRelationship;

  Stream<String> streamReply(ReplyRequest request);

  /// The relationship event the finished reply proposes, if any.
  Future<RelationshipProposalDraft?> relationshipProposal(
    ReplyRequest request,
    String finalText,
  );
}

class FakeReplyStreamingService implements ReplyStreamingService {
  FakeReplyStreamingService({
    this.isOffline = _never,
    this.thinkingDelay = const Duration(milliseconds: 900),
    this.tick = const Duration(milliseconds: 60),
    this.wordsPerTick = 3,
  });

  static bool _never() => false;

  @override
  bool get handlesRelationship => false;

  final bool Function() isOffline;
  final Duration thinkingDelay;
  final Duration tick;
  final int wordsPerTick;

  int _counter = 0;

  /// Picks the next canned reply for the character, never the same as
  /// [avoid] when there is a choice (mirrors the prototype's `nextReply`).
  String nextReply(Character c, {String? avoid, String tier = 'guarded'}) {
    final list =
        MockData.repliesTier[c.id]?[tier] ??
        MockData.replies[c.id] ??
        MockData.replies['_default']!;
    String pick() => list[(_counter++) % list.length];
    var t = pick();
    if (t == avoid && list.length > 1) t = pick();
    return t.replaceAll('{name}', c.first);
  }

  /// Canned replies that show a character opening up propose one event,
  /// with the quote as evidence (like the model output contract).
  @override
  Future<RelationshipProposalDraft?> relationshipProposal(
    ReplyRequest request,
    String finalText,
  ) async {
    const known = {
      "I haven't shown that to anyone": (
        'vulnerability_shared',
        'Vesper showed the logbook',
      ),
      "I'd rather not lose anyone else to it": (
        'vulnerability_shared',
        'Vesper spoke about who the sea took',
      ),
    };
    for (final e in known.entries) {
      if (request.character.id == 'vesper' && finalText.contains(e.key)) {
        return RelationshipProposalDraft(
          kindId: e.value.$1,
          evidence: e.key,
          reason: e.value.$2,
        );
      }
    }
    return null;
  }

  @override
  Stream<String> streamReply(ReplyRequest request) async* {
    if (isOffline()) {
      await Future<void>.delayed(thinkingDelay);
      throw const OfflineException();
    }
    final full = nextReply(
      request.character,
      avoid: request.avoidText,
      tier: request.tier,
    );
    await Future<void>.delayed(thinkingDelay);
    if (!request.stream) {
      yield full;
      return;
    }
    // Split keeping whitespace so paragraphs and spacing survive.
    final parts = full.split(RegExp(r'(?<=\s)(?=\S)'));
    final shown = StringBuffer();
    for (var i = 0; i < parts.length; i++) {
      shown.write(parts[i]);
      if ((i + 1) % wordsPerTick == 0 || i == parts.length - 1) {
        yield shown.toString();
        if (i != parts.length - 1) await Future<void>.delayed(tick);
      }
    }
  }
}

final replyStreamingServiceProvider = Provider<ReplyStreamingService>((ref) {
  final api = ref.watch(backendApiProvider);
  if (api != null) return ServerReplyStreamingService(api);
  return FakeReplyStreamingService(
    isOffline: () {
      if (ref.read(mockScenarioProvider) == MockScenario.offline) return true;
      if (ref.read(mockFailNextReplyProvider)) {
        ref.read(mockFailNextReplyProvider.notifier).state = false;
        return true;
      }
      return false;
    },
  );
});
