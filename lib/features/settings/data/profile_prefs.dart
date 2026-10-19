import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/backend/backend_providers.dart';

/// "Mature content": whether replies may include romance and adult themes
/// between adult characters. Off by default. The choice is stored in your
/// account and the server's prompt follows it (the app never builds prompts);
/// the rule that everyone in a story is an adult is always on and cannot be
/// switched off from here.
class MatureContentNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final api = ref.watch(backendApiProvider);
    ref.watch(backendUserIdProvider);
    final uid = api?.userId;
    if (api == null || uid == null) return false;
    final rows = await api.select(
      'profiles',
      columns: 'adult_content',
      eq: {'id': uid},
      limit: 1,
    );
    return rows.isNotEmpty && rows.first['adult_content'] == true;
  }

  Future<void> set(bool on) async {
    final api = ref.read(backendApiProvider);
    final uid = api?.userId;
    if (api == null || uid == null) return;
    final before = state;
    state = AsyncData(on);
    try {
      await api.update('profiles', {'adult_content': on}, eq: {'id': uid});
    } catch (_) {
      state = before;
      rethrow;
    }
  }
}

final matureContentProvider =
    AsyncNotifierProvider<MatureContentNotifier, bool>(
      MatureContentNotifier.new,
    );
