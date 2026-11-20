import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/auth/auth_state.dart';
import '../core/notifications/push_notifications.dart';
import '../core/observability/observability.dart';
import '../l10n/app_localizations.dart';
import 'router.dart';
import 'theme/app_theme.dart';
import 'theme/color_tokens.dart';
import 'theme/tema_provider.dart';

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
      themeMode: ref.watch(temaProvider),
      builder: construirConModo,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    );
  }
}

/// Un único sitio decide el modo activo. Las pantallas leen `AppColors`, que
/// no avisa al cambiar: por eso, al cambiar de modo, se vuelve a dibujar todo
/// lo que hay debajo ([redibujarTodo]) y ninguna pantalla —ni una `const`— se
/// queda con los colores del modo anterior.
Widget construirConModo(BuildContext context, Widget? child) {
  final paleta = Theme.of(context).brightness == Brightness.dark
      ? AppPalette.dark
      : AppPalette.light;
  if (AppColors.paleta != paleta) {
    AppColors.usar(paleta);
    WidgetsBinding.instance.addPostFrameCallback((_) => redibujarTodo());
  }
  return child ?? const SizedBox.shrink();
}

/// Marca todos los elementos para dibujarse de nuevo, también los `const`,
/// que Flutter se salta cuando solo cambia un valor global. Conserva el
/// estado de las pantallas (posición del scroll, textos escritos): solo
/// repinta.
void redibujarTodo() {
  void marca(Element e) {
    e.markNeedsBuild();
    e.visitChildren(marca);
  }

  WidgetsBinding.instance.rootElement?.visitChildren(marca);
}
