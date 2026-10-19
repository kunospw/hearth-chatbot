import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/backend/backend_config.dart';
import 'auth_service.dart';

/// Which server the app talks to. Not configured = built-in sample data.
final backendConfigProvider = Provider<BackendConfig>(
  (ref) => BackendConfig.fromEnvironment(),
);

/// The sign-in service, or null when there is no server (sample-data mode).
/// Main sets this up once Supabase is initialised; tests override it.
final authServiceProvider = Provider<AuthService?>((ref) => null);

/// The signed-in user. Everything that belongs to a person (their library,
/// chats, relationships) watches this, so signing out or switching accounts
/// rebuilds it from scratch.
class AuthUserNotifier extends Notifier<AuthUser?> {
  StreamSubscription<AuthUser?>? _sub;

  @override
  AuthUser? build() {
    final service = ref.watch(authServiceProvider);
    ref.onDispose(() => _sub?.cancel());
    if (service == null) return null;
    _sub = service.changes.listen((u) {
      if (u != state) state = u;
    });
    return service.current;
  }
}

final authUserProvider = NotifierProvider<AuthUserNotifier, AuthUser?>(
  AuthUserNotifier.new,
);

/// True when a server is set up and nobody is signed in yet.
final needsSignInProvider = Provider<bool>(
  (ref) =>
      ref.watch(authServiceProvider) != null &&
      ref.watch(authUserProvider) == null,
);
