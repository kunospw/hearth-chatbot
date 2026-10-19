import '../../../core/backend/backend_api.dart';
import '../../../core/backend/mappers.dart';
import '../domain/ai_model.dart';
import 'model_repository.dart';

/// The models you can pick, with their daily allowance. Only the friendly names
/// reach the app: which real model each one maps to is decided on the server.
class SupabaseModelRepository implements ModelRepository {
  SupabaseModelRepository(this.api);

  final BackendApi api;

  @override
  Future<List<AiModel>> list() async {
    final rows = await api.select(
      'models',
      columns: 'id,name,description,daily_free_replies,busy,sort',
      orderBy: 'sort',
    );
    return [for (final r in rows) modelFromRow(r)];
  }

  /// Free replies used today, by model id.
  Future<Map<String, int>> usedToday() async {
    final today = DateTime.now().toUtc().toIso8601String().substring(0, 10);
    final rows = await api.select('model_usage', eq: {'day': today});
    return {
      for (final r in rows) r['model_id'] as String: (r['used'] as num).toInt(),
    };
  }
}
