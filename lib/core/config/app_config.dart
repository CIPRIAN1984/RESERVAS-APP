/// Runtime configuration read from `--dart-define-from-file`.
/// See `dart_define.example.json` at the project root for the expected keys.
class AppConfig {
  AppConfig._();

  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const String stripePublishableKey = String.fromEnvironment('STRIPE_PUBLISHABLE_KEY');

  /// Sentry DSN for crash/error reporting. Optional: when empty, Sentry stays
  /// disabled and the app runs normally (see `ObservabilityConfig`).
  static const String sentryDsn = String.fromEnvironment('SENTRY_DSN');

  /// Logical environment reported to Sentry (`development`, `staging`,
  /// `production`). Defaults to `development` so local runs are separable.
  static const String environmentName =
      String.fromEnvironment('APP_ENV', defaultValue: 'development');

  static bool get isConfigured => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  static bool get isSentryEnabled => sentryDsn.isNotEmpty;
}
