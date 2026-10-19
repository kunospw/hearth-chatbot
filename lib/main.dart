import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/backend/backend_config.dart';
import 'core/backend/backend_providers.dart';
import 'core/backend/supabase_api.dart';
import 'core/theme/theme_provider.dart';
import 'features/auth/data/auth_providers.dart';
import 'features/auth/data/auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  final prefs = await SharedPreferences.getInstance();

  // With a project configured (--dart-define SUPABASE_URL / SUPABASE_ANON_KEY)
  // the app signs in and uses your account; without one it runs on built-in
  // sample data. Only the project URL and the anon key are in the app: what a
  // signed-in user may do is decided by row-level security on the server, and
  // the model key stays on the server.
  const config = BackendConfig.fromEnvironment();
  final overrides = <Override>[
    sharedPreferencesProvider.overrideWithValue(prefs),
  ];
  if (config.isConfigured) {
    await Supabase.initialize(url: config.url, publishableKey: config.anonKey);
    overrides.addAll([
      backendConfigProvider.overrideWithValue(config),
      authServiceProvider.overrideWithValue(SupabaseAuthService()),
      backendApiProvider.overrideWithValue(SupabaseBackendApi(config)),
    ]);
  }
  runApp(ProviderScope(overrides: overrides, child: const HearthApp()));
}
