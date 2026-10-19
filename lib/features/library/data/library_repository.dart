import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/backend/backend_providers.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../data/mock/mock_data.dart';
import '../domain/library_models.dart';
import 'supabase_library_repository.dart';

abstract interface class LibraryRepository {
  Future<List<Universe>> universes();
  Future<Universe?> universeById(String id);
  Future<void> saveUniverse(Universe universe);

  /// All memories, or only those of [universeId].
  Future<List<Memory>> memories({String? universeId});
  Future<void> saveMemory(Memory memory);
  Future<void> deleteMemory(String id);

  Future<List<Persona>> personas();
  Future<void> savePersona(Persona persona);
}

class MockLibraryRepository implements LibraryRepository {
  MockLibraryRepository()
    : _universes = List.of(MockData.universes),
      _memories = List.of(MockData.memories),
      _personas = List.of(MockData.personas);

  final List<Universe> _universes;
  final List<Memory> _memories;
  final List<Persona> _personas;

  @override
  Future<List<Universe>> universes() async => List.unmodifiable(_universes);

  @override
  Future<Universe?> universeById(String id) async {
    for (final u in _universes) {
      if (u.id == id) return u;
    }
    return null;
  }

  @override
  Future<void> saveUniverse(Universe universe) async {
    final i = _universes.indexWhere((u) => u.id == universe.id);
    if (i < 0) {
      _universes.add(universe);
    } else {
      _universes[i] = universe;
    }
  }

  @override
  Future<List<Memory>> memories({String? universeId}) async => [
    for (final m in _memories)
      if (universeId == null || m.universeId == universeId) m,
  ];

  @override
  Future<void> saveMemory(Memory memory) async {
    final i = _memories.indexWhere((m) => m.id == memory.id);
    if (i < 0) {
      _memories.add(memory);
    } else {
      _memories[i] = memory;
    }
  }

  @override
  Future<void> deleteMemory(String id) async =>
      _memories.removeWhere((m) => m.id == id);

  @override
  Future<List<Persona>> personas() async => List.unmodifiable(_personas);

  @override
  Future<void> savePersona(Persona persona) async {
    final i = _personas.indexWhere((p) => p.id == persona.id);
    if (i < 0) {
      _personas.add(persona);
    } else {
      _personas[i] = persona;
    }
  }
}

final libraryRepositoryProvider = Provider<LibraryRepository>((ref) {
  final api = ref.watch(backendApiProvider);
  ref.watch(backendUserIdProvider);
  return api != null ? SupabaseLibraryRepository(api) : MockLibraryRepository();
});

const _uuid = Uuid();

/// Universes. New ones take the next tile colour from the editor's swatches.
class UniversesNotifier extends AsyncNotifier<List<Universe>> {
  @override
  Future<List<Universe>> build() =>
      ref.watch(libraryRepositoryProvider).universes();

  LibraryRepository get _repo => ref.read(libraryRepositoryProvider);

  Universe? byId(String id) {
    for (final u in state.valueOrNull ?? const <Universe>[]) {
      if (u.id == id) return u;
    }
    return null;
  }

  /// Creates a universe and returns it.
  Future<Universe> create({
    required String name,
    required String description,
  }) async {
    final list = state.valueOrNull ?? const <Universe>[];
    final sw = MockData.swatches[list.length % MockData.swatches.length];
    final u = Universe(
      id: _uuid.v4(),
      name: name.trim(),
      era: 'Your own world',
      tile: sw.tile,
      description: description.trim(),
    );
    await _repo.saveUniverse(u);
    state = AsyncData([...list, u]);
    return u;
  }

  Future<void> edit(
    String id, {
    required String name,
    required String description,
  }) async {
    final list = state.valueOrNull ?? const <Universe>[];
    final i = list.indexWhere((u) => u.id == id);
    if (i < 0) return;
    final next = list[i].copyWith(
      name: name.trim(),
      description: description.trim(),
    );
    await _repo.saveUniverse(next);
    state = AsyncData([...list]..[i] = next);
  }
}

final universesProvider =
    AsyncNotifierProvider<UniversesNotifier, List<Universe>>(
      UniversesNotifier.new,
    );

/// A memory that was just deleted, so Undo can put it back where it was.
class RemovedMemory {
  const RemovedMemory(this.memory, this.index);
  final Memory memory;
  final int index;
}

/// All memories. Pinning keeps an item where it is (no re-sorting).
class MemoriesNotifier extends AsyncNotifier<List<Memory>> {
  @override
  Future<List<Memory>> build() =>
      ref.watch(libraryRepositoryProvider).memories();

  LibraryRepository get _repo => ref.read(libraryRepositoryProvider);
  List<Memory> get _list => state.valueOrNull ?? const <Memory>[];

  Future<void> add({
    required String universeId,
    required MemoryCategory category,
    required String text,
    bool pinned = false,
  }) async {
    final m = Memory(
      id: _uuid.v4(),
      universeId: universeId,
      category: category,
      text: text.trim(),
      pinned: pinned,
    );
    await _repo.saveMemory(m);
    state = AsyncData([..._list, m]);
  }

  Future<void> edit(Memory m) async {
    final i = _list.indexWhere((x) => x.id == m.id);
    if (i < 0) return;
    await _repo.saveMemory(m);
    state = AsyncData([..._list]..[i] = m);
  }

  Future<void> togglePin(String id) async {
    final i = _list.indexWhere((x) => x.id == id);
    if (i < 0) return;
    await edit(_list[i].copyWith(pinned: !_list[i].pinned));
  }

  /// Deletes a memory; pass the result to [restore] for Undo.
  Future<RemovedMemory?> remove(String id) async {
    final i = _list.indexWhere((x) => x.id == id);
    if (i < 0) return null;
    final removed = RemovedMemory(_list[i], i);
    await _repo.deleteMemory(id);
    state = AsyncData([..._list]..removeAt(i));
    return removed;
  }

  Future<void> restore(RemovedMemory r) async {
    await _repo.saveMemory(r.memory);
    final copy = [..._list];
    copy.insert(r.index.clamp(0, copy.length), r.memory);
    state = AsyncData(copy);
  }
}

final memoriesProvider = AsyncNotifierProvider<MemoriesNotifier, List<Memory>>(
  MemoriesNotifier.new,
);

/// Personas (who you play as).
class PersonasNotifier extends AsyncNotifier<List<Persona>> {
  @override
  Future<List<Persona>> build() =>
      ref.watch(libraryRepositoryProvider).personas();

  Future<Persona> add({
    required String name,
    required String description,
  }) async {
    final n = name.trim();
    final p = Persona(
      id: _uuid.v4(),
      name: n,
      initial: n.isEmpty ? '?' : n.substring(0, 1).toUpperCase(),
      description: description.trim(),
    );
    await ref.read(libraryRepositoryProvider).savePersona(p);
    state = AsyncData([...(state.valueOrNull ?? const <Persona>[]), p]);
    return p;
  }
}

final personasProvider = AsyncNotifierProvider<PersonasNotifier, List<Persona>>(
  PersonasNotifier.new,
);

const _personaKey = 'selected_persona';

/// Who you are in your stories. Persisted.
class SelectedPersonaNotifier extends Notifier<String> {
  @override
  String build() =>
      ref.read(sharedPreferencesProvider).getString(_personaKey) ??
      MockData.personas.first.id;

  void select(String id) {
    state = id;
    ref.read(sharedPreferencesProvider).setString(_personaKey, id);
  }
}

final selectedPersonaIdProvider =
    NotifierProvider<SelectedPersonaNotifier, String>(
      SelectedPersonaNotifier.new,
    );

/// The persona actually in use: your choice if it still exists, otherwise the
/// first one ("Just me" on a server, where the stored choice may be stale).
final activePersonaIdProvider = Provider<String>((ref) {
  final chosen = ref.watch(selectedPersonaIdProvider);
  final list = ref.watch(personasProvider).valueOrNull;
  if (list == null || list.isEmpty || list.any((p) => p.id == chosen)) {
    return chosen;
  }
  return list.first.id;
});
