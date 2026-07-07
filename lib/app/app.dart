import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/auth/auth_state.dart';
import '../core/observability/observability.dart';
import 'router.dart';
import 'theme/app_theme.dart';

class ItacaApp extends ConsumerWidget {
  const ItacaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Tag Sentry events with the current user id (no PII) as sessions change.
    ref.listen(currentUserIdProvider, (_, userId) => Observability.setUser(userId));

    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'ITACA',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      routerConfig: router,
    );
  }
}
