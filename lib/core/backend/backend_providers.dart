import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/data/auth_providers.dart';
import 'backend_api.dart';

/// The server connection, or null in sample-data mode (no project configured).
/// `main` provides the real one; tests provide an in-memory fake.
final backendApiProvider = Provider<BackendApi?>((ref) => null);

/// The signed-in user's id for repositories to rebuild on. Switching or
/// signing out gives every repository (and the data it loaded) a fresh start.
final backendUserIdProvider = Provider<String?>((ref) {
  ref.watch(authUserProvider);
  return ref.watch(backendApiProvider)?.userId;
});

/// True when the app runs against a server (Supabase), false on sample data.
final usesBackendProvider = Provider<bool>(
  (ref) => ref.watch(backendApiProvider) != null,
);
