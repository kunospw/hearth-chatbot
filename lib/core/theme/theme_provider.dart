import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'hearth_theme.dart';

/// Overridden in `main()` once SharedPreferences has loaded.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPreferencesProvider not overridden'),
);

const _themeKey = 'theme_choice';

class ThemeChoiceNotifier extends Notifier<HearthThemeChoice> {
  @override
  HearthThemeChoice build() {
    final saved = ref.read(sharedPreferencesProvider).getString(_themeKey);
    return HearthThemeChoice.values.firstWhere(
      (c) => c.name == saved,
      orElse: () => HearthThemeChoice.dark,
    );
  }

  void set(HearthThemeChoice choice) {
    state = choice;
    ref.read(sharedPreferencesProvider).setString(_themeKey, choice.name);
  }
}

final themeChoiceProvider =
    NotifierProvider<ThemeChoiceNotifier, HearthThemeChoice>(
      ThemeChoiceNotifier.new,
    );
