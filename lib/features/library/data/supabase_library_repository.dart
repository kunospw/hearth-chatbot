import '../../../core/backend/backend_api.dart';
import '../../../core/backend/mappers.dart';
import '../domain/library_models.dart';
import 'library_repository.dart';

/// Universes, memories and personas stored in your account.
class SupabaseLibraryRepository implements LibraryRepository {
  SupabaseLibraryRepository(this.api);

  final BackendApi api;

  String get _uid =>
      api.userId ??
      (throw const BackendException(401, 'unauthorized', 'Sign in first.'));

  @override
  Future<List<Universe>> universes() async => [
    for (final r in await api.select('universes', orderBy: 'created_at'))
      universeFromRow(r),
  ];

  @override
  Future<Universe?> universeById(String id) async {
    final rows = await api.select('universes', eq: {'id': id}, limit: 1);
    return rows.isEmpty ? null : universeFromRow(rows.first);
  }

  @override
  Future<void> saveUniverse(Universe universe) =>
      api.upsert('universes', universeToRow(universe, userId: _uid));

  @override
  Future<List<Memory>> memories({String? universeId}) async => [
    for (final r in await api.select(
      'memories',
      eq: {'universe_id': ?universeId},
      orderBy: 'pos',
    ))
      memoryFromRow(r),
  ];

  @override
  Future<void> saveMemory(Memory memory) =>
      api.upsert('memories', memoryToRow(memory, userId: _uid));

  @override
  Future<void> deleteMemory(String id) =>
      api.delete('memories', eq: {'id': id});

  @override
  Future<List<Persona>> personas() async {
    // "Just me" (the default) comes first, then the rest in the order they were made.
    final rows = await api.select('personas', orderBy: 'created_at');
    rows.sort(
      (a, b) =>
          (b['is_default'] == true ? 1 : 0) - (a['is_default'] == true ? 1 : 0),
    );
    return [for (final r in rows) personaFromRow(r)];
  }

  @override
  Future<void> savePersona(Persona persona) =>
      api.upsert('personas', personaToRow(persona, userId: _uid));
}
