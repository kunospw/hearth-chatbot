import '../../../core/backend/backend_api.dart';
import '../../../core/backend/mappers.dart';
import '../domain/character.dart';
import 'character_repository.dart';

/// Characters stored in your account. Each row is yours alone (row-level security).
class SupabaseCharacterRepository implements CharacterRepository {
  SupabaseCharacterRepository(this.api);

  final BackendApi api;

  String get _uid =>
      api.userId ??
      (throw const BackendException(401, 'unauthorized', 'Sign in first.'));

  @override
  Future<List<Character>> list() async {
    final rows = await api.select(
      'characters',
      orderBy: 'created_at',
      ascending: false,
    );
    return [for (final r in rows) characterFromRow(r)];
  }

  @override
  Future<Character?> byId(String id) async {
    final rows = await api.select('characters', eq: {'id': id}, limit: 1);
    return rows.isEmpty ? null : characterFromRow(rows.first);
  }

  @override
  Future<void> delete(String id) => api.delete('characters', eq: {'id': id});

  @override
  Future<void> save(Character character) async {
    // A picture chosen on this device is uploaded and replaced by its address.
    String? url;
    final bytes = character.portraitBytes;
    if (bytes != null) url = await api.uploadPortrait(bytes);
    await api.upsert(
      'characters',
      characterToRow(character, userId: _uid, portraitUrl: url),
    );
  }
}
