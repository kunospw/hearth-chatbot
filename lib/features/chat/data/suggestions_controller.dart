import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/mock/mock_scenario.dart';
import '../../characters/data/character_repository.dart';
import '../../library/data/library_repository.dart';
import '../../settings/data/model_usage.dart';
import 'conversation_repository.dart';
import 'suggestion_service.dart';

enum SuggestStatus { idle, loading, ready, failed }

@immutable
class SuggestionsState {
  const SuggestionsState({
    this.status = SuggestStatus.idle,
    this.items = const [],
    this.forMessageId,
    this.error,
  });

  final SuggestStatus status;
  final List<String> items;

  /// The last message of the chat when these were written. Once the chat moves
  /// on (you sent something, a reply arrived) they are out of date.
  final String? forMessageId;
  final String? error;
}

/// Reply ideas for one chat. Not remembered across sessions.
class SuggestionsController extends FamilyNotifier<SuggestionsState, String> {
  @override
  SuggestionsState build(String arg) => const SuggestionsState();

  Future<void> fetch() async {
    if (state.status == SuggestStatus.loading) return;
    final conv = ref.read(conversationProvider(arg));
    if (conv == null) return;
    final character = await ref.read(characterRepositoryProvider).byId(conv.characterId);
    if (character == null) return;
    final forId = conv.last?.id;
    state = SuggestionsState(status: SuggestStatus.loading, forMessageId: forId);
    try {
      // The server reads your saved chat: make sure it is saved.
      await ref.read(conversationsProvider.notifier).flush(arg);
      await ref.read(personasProvider.future);
      final items = await ref.read(suggestionServiceProvider).suggest(
            conversationId: arg,
            personaId: conv.personaId ?? ref.read(activePersonaIdProvider),
            modelId: ref.read(selectedModelIdProvider),
            character: character,
          );
      state = SuggestionsState(status: SuggestStatus.ready, items: items, forMessageId: forId);
    } on OfflineException {
      state = SuggestionsState(
        status: SuggestStatus.failed,
        error: 'Can’t reach Hearth. Check your connection.',
        forMessageId: forId,
      );
    } on SuggestionFailed catch (e) {
      state = SuggestionsState(status: SuggestStatus.failed, error: e.message, forMessageId: forId);
    } catch (_) {
      state = SuggestionsState(
        status: SuggestStatus.failed,
        error: 'Couldn’t come up with ideas. Try again.',
        forMessageId: forId,
      );
    }
  }

  void clear() => state = const SuggestionsState();
}

final suggestionsProvider =
    NotifierProvider.family<SuggestionsController, SuggestionsState, String>(SuggestionsController.new);
