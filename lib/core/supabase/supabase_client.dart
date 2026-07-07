import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';

/// Thin wrapper around the singleton Supabase client so feature repositories
/// import this instead of reaching into `supabase_flutter` directly.
class AppSupabase {
  AppSupabase._();

  static SupabaseClient get client => Supabase.instance.client;

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      publishableKey: AppConfig.supabaseAnonKey,
    );
  }
}
