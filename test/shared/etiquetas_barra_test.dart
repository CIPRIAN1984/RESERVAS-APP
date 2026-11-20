import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:itaca/app/app_mode.dart';
import 'package:itaca/app/routes.dart';
import 'package:itaca/app/theme/app_theme.dart';
import 'package:itaca/core/auth/auth_state.dart';
import 'package:itaca/core/models/profile.dart';
import 'package:itaca/shared/navigation/main_shell.dart';

import '../golden_archived/ayuda_golden.dart';

/// En el móvil de Cipri (412 px) la barra del modo Gestor tiene seis sitios y
/// «Herramientas» se partía en dos líneas («Herramienta» / «s»). Con las
/// tipografías reales, cada etiqueta tiene que ocupar una sola línea.
///
/// Límite conocido: en móviles de 360 px de ancho «Herramientas» sigue sin
/// caber a 10 px; haría falta una etiqueta más corta (decisión de Cipri).

class _ModoGestor extends AppModeNotifier {
  @override
  AppMode build() => AppMode.gestor;
}

Widget _app() {
  final router = GoRouter(
    initialLocation: Routes.inicio,
    routes: [
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          for (final r in [
            Routes.inicio,
            Routes.herramientas,
            Routes.miembros,
            Routes.novedades,
            Routes.academia,
          ])
            GoRoute(path: r, builder: (_, _) => const SizedBox.shrink()),
        ],
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      currentProfileProvider.overrideWith(
        (ref) async => Profile(
          id: 'u1',
          academiaId: 'a1',
          rol: 'dueño',
          nombre: 'Cipri',
          estado: 'activo',
        ),
      ),
      appModeProvider.overrideWith(_ModoGestor.new),
    ],
    child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
  );
}

void main() {
  setUpAll(cargarTipografias);

  for (final (ancho, letra) in [(412.0, 1.0), (393.0, 1.0), (412.0, 1.3)]) {
    testWidgets('las etiquetas de la barra caben en una línea a $ancho px '
        '(letra x$letra)', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = letra;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.binding.setSurfaceSize(Size(ancho, 800));
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      for (final etiqueta in [
        'Hoy',
        'Herramientas',
        'Miembros',
        'Novedades',
        'Academia',
      ]) {
        final alto = tester
            .getSize(
              find
                  .descendant(
                    of: find.byType(NavigationBar),
                    matching: find.text(etiqueta),
                  )
                  .first,
            )
            .height;
        // Una línea de 10 px mide ~12-13; dos, ~25.
        expect(
          alto,
          lessThan(16),
          reason: '«$etiqueta» ocupa $alto px de alto',
        );
      }
    });
  }
}
