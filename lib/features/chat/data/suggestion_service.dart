import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/backend/backend_api.dart';
import '../../../core/backend/backend_providers.dart';
import '../../../data/mock/mock_scenario.dart';
import '../../characters/domain/character.dart';

/// Ideas for what you could say next, written as you. Nothing is sent: you pick
/// one, change it, and send it yourself.
abstract interface class SuggestionService {
  Future<List<String>> suggest({
    required String conversationId,
    required String personaId,
    required String modelId,
    required Character character,
    int count,
  });
}

/// Why no ideas came back, in words a person can read.
class SuggestionFailed implements Exception {
  const SuggestionFailed(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Sample-data mode: a few generic ideas, so the button can be tried.
class MockSuggestionService implements SuggestionService {
  MockSuggestionService({this.delay = const Duration(milliseconds: 700)});

  final Duration delay;
  int _n = 0;

  @override
  Future<List<String>> suggest({
    required String conversationId,
    required String personaId,
    required String modelId,
    required Character character,
    int count = 3,
  }) async {
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    final f = character.first;
    final all = [
      '*I tilt my head.* What are you not telling me, $f?',
      'Tell me more. I have all night.',
      '*I step a little closer.* You make that sound like a warning.',
      'Fine. Then show me what you meant.',
      '*I smile.* I’m starting to like this.',
      'Why do I get the feeling you’ve been waiting for me?',
    ];
    final start = (_n++ * 3) % all.length;
    return [for (var i = 0; i < count; i++) all[(start + i) % all.length]];
  }
}

/// The server writes them (it knows your chat, your persona and the content
/// settings). Asked only when you tap the button.
class ServerSuggestionService implements SuggestionService {
  ServerSuggestionService(this.api);

  final BackendApi api;

  @override
  Future<List<String>> suggest({
    required String conversationId,
    required String personaId,
    required String modelId,
    required Character character,
    int count = 3,
  }) async {
    try {
      final res = await api.invoke('suggest_replies', {
        'conversationId': conversationId,
        'personaId': personaId,
        'modelId': modelId,
        'count': count,
      });
      final list = [
        for (final s in (res['suggestions'] as List? ?? const []))
          if (s is String && s.trim().isNotEmpty) s.trim(),
      ];
      if (list.isEmpty) throw const SuggestionFailed('No ideas this time. Try again.');
      return list;
    } on OfflineBackendException {
      throw const OfflineException();
    } on BackendException catch (e) {
      throw SuggestionFailed(e.message);
    }
  }
}

final suggestionServiceProvider = Provider<SuggestionService>((ref) {
  final api = ref.watch(backendApiProvider);
  return api != null ? ServerSuggestionService(api) : MockSuggestionService();
});
