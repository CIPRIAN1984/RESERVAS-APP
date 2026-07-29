import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'app/app.dart';
import 'app/theme/app_theme.dart';
import 'core/config/app_config.dart';
import 'core/observability/observability.dart';
import 'core/supabase/supabase_client.dart';

Future<void> main() async {
  // Everything runs inside the Sentry zone (a no-op when SENTRY_DSN is unset),
  // so uncaught errors during startup are captured too.
  await Observability.run(() async {
    WidgetsFlutterBinding.ensureInitialized();
    await initializeDateFormatting('es_ES');
    Intl.defaultLocale = 'es_ES';

    if (!AppConfig.isConfigured) {
      runApp(const _MissingConfigApp());
      return;
    }

    if (AppConfig.stripePublishableKey.isNotEmpty) {
      Stripe.publishableKey = AppConfig.stripePublishableKey;
      // Not awaited: this talks to the native Stripe SDK, which has been
      // observed to stall on some real-device networks. The app's first frame
      // must never depend on it — nothing needs Stripe configured until a
      // payment screen actually opens, by which point this has long finished.
      unawaited(Stripe.instance.applySettings());
    }

    await AppSupabase.initialize();
    runApp(const ProviderScope(child: ItacaApp()));
  });
}

/// Shown instead of crashing when SUPABASE_URL/SUPABASE_ANON_KEY weren't
/// passed via --dart-define-from-file. See dart_define.example.json.
class _MissingConfigApp extends StatelessWidget {
  const _MissingConfigApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Text(
              'Falta configuración de Supabase.\n\n'
              'Copia dart_define.example.json a dart_define.json, rellena '
              'SUPABASE_URL y SUPABASE_ANON_KEY, y ejecuta con:\n'
              'flutter run --dart-define-from-file=dart_define.json',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
