import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/character_form.dart';

/// Saved character drafts (newest first). Kept in memory for now.
class DraftsNotifier extends Notifier<List<CharacterDraft>> {
  @override
  List<CharacterDraft> build() => const [];

  CharacterDraft? byId(String id) {
    for (final d in state) {
      if (d.id == id) return d;
    }
    return null;
  }

  /// Adds a draft or replaces the one with the same id.
  void save(CharacterDraft draft) {
    final without = state.where((d) => d.id != draft.id).toList();
    state = [draft, ...without];
  }

  void remove(String id) => state = state.where((d) => d.id != id).toList();
}

final draftsProvider = NotifierProvider<DraftsNotifier, List<CharacterDraft>>(
  DraftsNotifier.new,
);
