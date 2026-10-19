import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/backend/backend_providers.dart';
import '../../../data/mock/mock_data.dart';
import '../../../data/mock/mock_scenario.dart';
import '../domain/ai_model.dart';
import 'supabase_model_repository.dart';

abstract interface class ModelRepository {
  Future<List<AiModel>> list();
}

class MockModelRepository implements ModelRepository {
  MockModelRepository({this.latency = Duration.zero});

  final Duration latency;

  @override
  Future<List<AiModel>> list() async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    return MockData.models;
  }
}

final modelRepositoryProvider = Provider<ModelRepository>((ref) {
  final api = ref.watch(backendApiProvider);
  if (api != null) return SupabaseModelRepository(api);
  return MockModelRepository(latency: ref.watch(mockLatencyProvider) ~/ 2);
});

final modelsProvider = FutureProvider<List<AiModel>>(
  (ref) => ref.watch(modelRepositoryProvider).list(),
);
