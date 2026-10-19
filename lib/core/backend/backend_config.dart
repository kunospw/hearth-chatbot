/// Where the app finds its server. Nothing secret lives here: the project URL
/// and the *anon* (publishable) key are meant to ship inside the app (what a user can do is
/// decided by row-level security on the server). Pass them at build time:
///
///   flutter run --dart-define=SUPABASE_URL=https://xyz.supabase.co \
///               --dart-define=SUPABASE_ANON_KEY=eyJ...
///
/// Without them the app runs entirely on built-in sample data (no sign-in),
/// which is also what the tests use. The model key (Ollama) never reaches the
/// device at all: it is a secret of the server functions.
class BackendConfig {
  const BackendConfig({required this.url, required this.anonKey});

  const BackendConfig.fromEnvironment()
    : url = const String.fromEnvironment('SUPABASE_URL'),
      anonKey = const String.fromEnvironment('SUPABASE_ANON_KEY');

  final String url;
  final String anonKey;

  bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;
}
