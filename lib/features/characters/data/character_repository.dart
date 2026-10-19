import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/backend/backend_providers.dart';
import '../../../data/mock/mock_data.dart';
import '../../../data/mock/mock_scenario.dart';
import '../../chat/data/conversation_repository.dart';
import '../../chat/domain/chat_models.dart';
import '../domain/character.dart';
import 'supabase_character_repository.dart';

abstract interface class CharacterRepository {
  Future<List<Character>> list();
  Future<Character?> byId(String id);

  /// Inserts a new character (at the front) or replaces one with the same id.
  Future<void> save(Character character);

  /// Removes the character for good.
  Future<void> delete(String id);
}

class MockCharacterRepository implements CharacterRepository {
  MockCharacterRepository({
    this.scenario = MockScenario.normal,
    this.latency = Duration.zero,
  }) : _items = scenario == MockScenario.empty
           ? []
           : List.of(MockData.characters);

  final MockScenario scenario;
  final Duration latency;
  final List<Character> _items;

  Future<void> _gate() async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    if (scenario == MockScenario.offline) throw const OfflineException();
  }

  @override
  Future<List<Character>> list() async {
    await _gate();
    return List.unmodifiable(_items);
  }

  @override
  Future<void> save(Character character) async {
    final i = _items.indexWhere((c) => c.id == character.id);
    if (i < 0) {
      _items.insert(0, character);
    } else {
      _items[i] = character;
    }
  }

  @override
  Future<void> delete(String id) async => _items.removeWhere((c) => c.id == id);

  @override
  Future<Character?> byId(String id) async {
    // Not gated by the offline scenario: a chat that is already open keeps its
    // character; only the lists go offline.
    if (latency > Duration.zero) await Future<void>.delayed(latency ~/ 4);
    for (final c in _items) {
      if (c.id == id) return c;
    }
    return null;
  }
}

final characterRepositoryProvider = Provider<CharacterRepository>((ref) {
  final api = ref.watch(backendApiProvider);
  ref.watch(backendUserIdProvider);
  if (api != null) return SupabaseCharacterRepository(api);
  return MockCharacterRepository(
    scenario: ref.watch(mockScenarioProvider),
    latency: ref.watch(mockLatencyProvider),
  );
});

/// All characters, newest first. Creating or editing one goes through here so
/// every screen updates.
class CharactersNotifier extends AsyncNotifier<List<Character>> {
  @override
  Future<List<Character>> build() =>
      ref.watch(characterRepositoryProvider).list();

  /// Saves a new or edited character and shows it everywhere.
  Future<void> save(Character c) async {
    await ref.read(characterRepositoryProvider).save(c);
    final list = state.valueOrNull ?? const <Character>[];
    final i = list.indexWhere((x) => x.id == c.id);
    // Parenthesised: a cascade binds looser than `?:`.
    state = AsyncData(i < 0 ? [c, ...list] : ([...list]..[i] = c));
  }

  /// Hides a character (and keeps it, with its chats) or brings it back.
  Future<void> setArchived(String id, bool archived) async {
    final c = (state.valueOrNull ?? const <Character>[])
        .where((x) => x.id == id)
        .firstOrNull;
    if (c != null) await save(c.copyWith(archived: archived));
  }

  /// Deletes a character for good, and every chat with them. (Their
  /// relationship goes with them on the server.)
  Future<void> delete(String id) async {
    final convs = ref.read(conversationsProvider.notifier);
    for (final c
        in ref.read(conversationsProvider).valueOrNull ??
            const <Conversation>[]) {
      if (c.characterId == id) await convs.delete(c.id);
    }
    await ref.read(characterRepositoryProvider).delete(id);
    state = AsyncData([
      for (final c in state.valueOrNull ?? const <Character>[])
        if (c.id != id) c,
    ]);
  }
}

final charactersProvider =
    AsyncNotifierProvider<CharactersNotifier, List<Character>>(
      CharactersNotifier.new,
    );

/// One character by id: loading while the list loads, null if it doesn't exist.
final characterProvider = Provider.family<AsyncValue<Character?>, String>((
  ref,
  id,
) {
  return ref.watch(charactersProvider).whenData((list) {
    for (final c in list) {
      if (c.id == id) return c;
    }
    return null;
  });
});
