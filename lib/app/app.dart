import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/auth/auth_state.dart';
import '../core/notifications/push_notifications.dart';
import '../core/observability/observability.dart';
import '../l10n/app_localizations.dart';
import 'router.dart';
import 'theme/app_theme.dart';

class ItacaApp extends ConsumerWidget {
  const ItacaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // React to session changes: tag Sentry (no PII) and register the device
    // for push once there's a signed-in user.
    ref.listen(currentUserIdProvider, (_, userId) {
      Observability.setUser(userId);
      if (userId != null) PushNotifications.registerForUser();
    });

    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      // Follows the OS light/dark setting instead of forcing dark.
      themeMode: ThemeMode.system,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    );
  }
}
