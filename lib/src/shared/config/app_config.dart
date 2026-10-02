/// Build-time configuration, supplied via `--dart-define` (or
/// `--dart-define-from-file=env.json`) so secrets are never committed.
///
/// The same values the web app uses (`VITE_SUPABASE_URL` /
/// `VITE_SUPABASE_ANON_KEY`): both apps talk to one Supabase project.
class AppConfig {
  const AppConfig._();

  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
  );

  /// Whether to show the "Create account" option. Mirrors the web
  /// `MULTI_USER_ENABLED` flag; sign-up must also be enabled in Supabase Auth.
  /// Defaults to on; pass `--dart-define=ALLOW_SIGNUP=false` to hide it.
  static const bool allowSignup = bool.fromEnvironment(
    'ALLOW_SIGNUP',
    defaultValue: true,
  );

  /// The web app's address. Email links (password reset, email change) are
  /// completed there, since this app doesn't handle deep links. Override with
  /// `--dart-define=WEB_URL=...` for a local or staging web build.
  static const String webUrl = String.fromEnvironment(
    'WEB_URL',
    defaultValue: 'https://archespace.app',
  );

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
