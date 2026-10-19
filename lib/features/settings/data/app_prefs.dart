import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_provider.dart';
import '../../chat/domain/chat_models.dart';

/// How relationship changes show during roleplay. Numbers are never shown.
enum RelationshipNotes {
  subtle('Subtle notes'),
  hidden('Hidden');

  const RelationshipNotes(this.label);
  final String label;
}

/// App-wide preferences from Settings. Persisted.
@immutable
class AppPrefs {
  const AppPrefs({
    this.defaultMode = ChatMode.chat,
    this.hidePreviews = true,
    this.blurSwitcher = false,
    this.relationshipNotes = RelationshipNotes.subtle,
    this.uiScale = 1,
  });

  /// New chats open in this mode.
  final ChatMode defaultMode;

  /// Notifications say "New reply" instead of showing text.
  final bool hidePreviews;

  /// Covers chats when switching apps.
  final bool blurSwitcher;

  /// "During roleplay" in the relationship journal.
  final RelationshipNotes relationshipNotes;

  /// App-wide text size (1 = normal), on top of the phone's own setting.
  final double uiScale;

  AppPrefs copyWith({
    ChatMode? defaultMode,
    bool? hidePreviews,
    bool? blurSwitcher,
    RelationshipNotes? relationshipNotes,
    double? uiScale,
  }) => AppPrefs(
    defaultMode: defaultMode ?? this.defaultMode,
    hidePreviews: hidePreviews ?? this.hidePreviews,
    blurSwitcher: blurSwitcher ?? this.blurSwitcher,
    relationshipNotes: relationshipNotes ?? this.relationshipNotes,
    uiScale: uiScale ?? this.uiScale,
  );
}

class AppPrefsNotifier extends Notifier<AppPrefs> {
  static const _k = 'app.';

  @override
  AppPrefs build() {
    final p = ref.read(sharedPreferencesProvider);
    return AppPrefs(
      defaultMode:
          ChatMode.values.asNameMap()[p.getString('${_k}defaultMode')] ??
          ChatMode.chat,
      hidePreviews: p.getBool('${_k}hidePreviews') ?? true,
      blurSwitcher: p.getBool('${_k}blurSwitcher') ?? false,
      relationshipNotes:
          RelationshipNotes.values.asNameMap()[p.getString('${_k}relNotes')] ??
          RelationshipNotes.subtle,
      uiScale: p.getDouble('${_k}uiScale') ?? 1,
    );
  }

  void _set(AppPrefs next) {
    state = next;
    final p = ref.read(sharedPreferencesProvider);
    p.setString('${_k}defaultMode', next.defaultMode.name);
    p.setBool('${_k}hidePreviews', next.hidePreviews);
    p.setBool('${_k}blurSwitcher', next.blurSwitcher);
    p.setString('${_k}relNotes', next.relationshipNotes.name);
    p.setDouble('${_k}uiScale', next.uiScale);
  }

  void setDefaultMode(ChatMode m) => _set(state.copyWith(defaultMode: m));
  void setHidePreviews(bool v) => _set(state.copyWith(hidePreviews: v));
  void setBlurSwitcher(bool v) => _set(state.copyWith(blurSwitcher: v));
  void setUiScale(double v) => _set(state.copyWith(uiScale: v));
  void setRelationshipNotes(RelationshipNotes v) =>
      _set(state.copyWith(relationshipNotes: v));
}

final appPrefsProvider = NotifierProvider<AppPrefsNotifier, AppPrefs>(
  AppPrefsNotifier.new,
);
