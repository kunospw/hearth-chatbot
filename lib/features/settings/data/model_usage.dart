import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/backend/backend_providers.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../data/mock/mock_data.dart';
import '../domain/ai_model.dart';
import 'model_repository.dart';
import 'supabase_model_repository.dart';

/// The models the app offers. With a server these come from the database (the
/// friendly names only: the real model behind each one stays on the server);
/// until they load, and in sample-data mode, the built-in list is used.
final modelCatalogProvider = Provider<List<AiModel>>((ref) {
  if (!ref.watch(usesBackendProvider)) return MockData.models;
  final list = ref.watch(modelsProvider).valueOrNull;
  return list == null || list.isEmpty ? MockData.models : list;
});

const _modelKey = 'selected_model';

/// The model used for new replies. Persisted.
class SelectedModelNotifier extends Notifier<String> {
  @override
  String build() =>
      ref.read(sharedPreferencesProvider).getString(_modelKey) ??
      MockData.models.first.id;

  void select(String id) {
    state = id;
    ref.read(sharedPreferencesProvider).setString(_modelKey, id);
  }
}

final selectedModelIdProvider = NotifierProvider<SelectedModelNotifier, String>(
  SelectedModelNotifier.new,
);

final selectedModelProvider = Provider<AiModel>((ref) {
  final id = ref.watch(selectedModelIdProvider);
  final all = ref.watch(modelCatalogProvider);
  return all.firstWhere((m) => m.id == id, orElse: () => all.first);
});

/// Free replies left today, per model. In sample-data mode this mirrors the
/// prototype's seed (Ember nearly used up, Lumen mostly fresh). With a server,
/// the server counts: this is loaded from it and refreshed by every reply.
/// A model that is not listed yet counts as having all its replies left.
class ModelUsageNotifier extends Notifier<Map<String, int>> {
  /// Models whose count the server has already reported during this session:
  /// a slower, older answer from the initial load must not overwrite them.
  final Set<String> _reported = {};

  @override
  Map<String, int> build() {
    if (!ref.watch(usesBackendProvider)) return const {'ember': 2, 'lumen': 41};
    ref.watch(backendUserIdProvider);
    _reported.clear();
    // Reload when the list of models arrives; keep what we know in the meantime.
    ref.listen(modelCatalogProvider, (_, next) => unawaited(_load(next)));
    unawaited(_load(ref.read(modelCatalogProvider)));
    return const {};
  }

  Future<void> _load(List<AiModel> models) async {
    final api = ref.read(backendApiProvider);
    if (api == null) return;
    try {
      final used = await SupabaseModelRepository(api).usedToday();
      state = {
        for (final m in models)
          if (m.dailyFreeReplies != null)
            m.id: _reported.contains(m.id)
                ? (state[m.id] ?? m.dailyFreeReplies!)
                : (m.dailyFreeReplies! - (used[m.id] ?? 0)).clamp(
                    0,
                    m.dailyFreeReplies!,
                  ),
      };
    } catch (_) {
      // Offline: the picker shows every allowance as unused until we can ask.
    }
  }

  /// The server says how many of today's free replies [modelId] has left.
  void setLeft(String modelId, int left) {
    _reported.add(modelId);
    state = {...state, modelId: left < 0 ? 0 : left};
  }

  void consume(String modelId) {
    final left = state[modelId];
    if (left == null) return;
    state = {...state, modelId: left > 0 ? left - 1 : 0};
  }

  void refund(String modelId) {
    final left = state[modelId];
    final cap = ref
        .read(modelCatalogProvider)
        .firstWhere((m) => m.id == modelId)
        .dailyFreeReplies;
    if (left == null || cap == null) return;
    state = {...state, modelId: left + 1 > cap ? cap : left + 1};
  }
}

final modelUsageProvider =
    NotifierProvider<ModelUsageNotifier, Map<String, int>>(
      ModelUsageNotifier.new,
    );

const resetsAtLabel = '07:00';

final modelStatusProvider = Provider.family<ModelStatus, String>((ref, id) {
  final model = ref.watch(modelCatalogProvider).firstWhere((m) => m.id == id);
  final left = ref.watch(modelUsageProvider)[id] ?? model.dailyFreeReplies;
  if (model.busy) {
    return const ModelStatus.unavailable('Busy right now — try again later');
  }
  if (model.dailyFreeReplies != null && (left ?? 0) <= 0) {
    return const ModelStatus.unavailable(
      'Daily limit reached · resets $resetsAtLabel',
    );
  }
  return ModelStatus.available(left);
});

extension ModelStatusText on ModelStatus {
  /// One-line status shown under a model in the picker.
  String line(AiModel model) {
    if (!available) return reason!;
    final cap = model.dailyFreeReplies;
    if (cap == null || repliesLeft == null) return 'Available';
    return 'Available · $repliesLeft of $cap free replies left today';
  }
}
