/// Runtime configuration read from `--dart-define-from-file`.
/// See `dart_define.example.json` at the project root for the expected keys.
class AppConfig {
  AppConfig._();

  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const String stripePublishableKey = String.fromEnvironment('STRIPE_PUBLISHABLE_KEY');

  static bool get isConfigured => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
