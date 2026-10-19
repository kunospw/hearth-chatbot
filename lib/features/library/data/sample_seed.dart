import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../data/mock/mock_data.dart';
import '../../characters/data/character_repository.dart';
import '../domain/library_models.dart';
import 'library_repository.dart';

const _uuid = Uuid();

/// True while the sample stories are being copied into your account.
final seedingProvider = StateProvider<bool>((ref) => false);

/// Copies the built-in sample world (universes, memories and the four sample
/// characters) into your account, with fresh ids, so a new account has someone
/// to talk to. Everything copied is yours to edit or delete afterwards.
Future<void> seedSampleStories(WidgetRef ref) async {
  if (ref.read(seedingProvider)) return;
  ref.read(seedingProvider.notifier).state = true;
  try {
    await _seed(ref);
  } finally {
    ref.read(seedingProvider.notifier).state = false;
  }
}

Future<void> _seed(WidgetRef ref) async {
  final library = ref.read(libraryRepositoryProvider);
  final characters = ref.read(characterRepositoryProvider);

  final universeIds = {for (final u in MockData.universes) u.id: _uuid.v4()};
  for (final u in MockData.universes) {
    await library.saveUniverse(
      Universe(
        id: universeIds[u.id]!,
        name: u.name,
        era: u.era,
        tile: u.tile,
        description: u.description,
      ),
    );
  }
  for (final m in MockData.memories) {
    final uni = universeIds[m.universeId];
    if (uni == null) continue;
    await library.saveMemory(
      Memory(
        id: _uuid.v4(),
        universeId: uni,
        category: m.category,
        text: m.text,
        pinned: m.pinned,
      ),
    );
  }
  // Oldest first, so the list (newest first) reads like the built-in one.
  for (final c in MockData.characters.reversed) {
    final uni = c.universeId == null ? null : universeIds[c.universeId];
    await characters.save(
      c.copyWith(id: _uuid.v4(), universeId: uni, clearUniverse: uni == null),
    );
  }
  ref.invalidate(universesProvider);
  ref.invalidate(memoriesProvider);
  ref.invalidate(charactersProvider);
}
