/// Build-time configuration, passed with --dart-define or
/// --dart-define-from-file=env.json (see env.example.json).
class Env {
  const Env._();

  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
  );

  /// Public address of the deployed web app, e.g. https://menu.example.com.
  /// QR codes and share links are built from it. On the web it defaults to the
  /// address the app is served from; the Android and iOS apps need it set.
  static const String publicBaseUrl = String.fromEnvironment('PUBLIC_BASE_URL');

  /// Where "Email support" points. The row is hidden when this is empty.
  static const String supportEmail = String.fromEnvironment('SUPPORT_EMAIL');

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
