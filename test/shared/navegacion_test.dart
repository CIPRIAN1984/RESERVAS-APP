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

/// Estando en Equipo o en Cobros no coincidía ninguna ruta de la barra, así
/// que se marcaba el primer destino: parecía que estabas en «Hoy» cuando
/// estabas en otra pantalla.

Profile _perfil({required String rol}) => Profile(
  id: 'u1',
  academiaId: 'a1',
  rol: rol,
  nombre: 'Riojano',
  apellidos: 'Ejemplo',
  estado: 'activo',
);

class _ModoFijo extends AppModeNotifier {
  _ModoFijo(this._inicial);
  final AppMode _inicial;
  @override
  AppMode build() => _inicial;
}

Widget _app({
  required String rol,
  required AppMode modo,
  required String ruta,
}) {
  final router = GoRouter(
    initialLocation: ruta,
    routes: [
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          for (final r in [
            Routes.inicio,
            Routes.estadisticas,
            Routes.novedades,
            Routes.perfil,
            Routes.herramientas,
            Routes.academia,
            Routes.miembros,
            Routes.equipo,
            Routes.ajustesReservas,
            Routes.tarifas,
            Routes.admin,
          ])
            GoRoute(path: r, builder: (_, _) => const SizedBox.shrink()),
        ],
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      currentProfileProvider.overrideWith((ref) async => _perfil(rol: rol)),
      appModeProvider.overrideWith(() => _ModoFijo(modo)),
    ],
    child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
  );
}

/// Qué destino aparece marcado en la barra inferior.
int _seleccionado(WidgetTester tester) {
  return tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex;
}

void main() {
  Future<void> montar(
    WidgetTester tester, {
    required String rol,
    required AppMode modo,
    required String ruta,
  }) async {
    await tester.binding.setSurfaceSize(const Size(412, 800));
    await tester.pumpWidget(_app(rol: rol, modo: modo, ruta: ruta));
    await tester.pumpAndSettle();
  }

  group('la barra marca dónde estás', () {
    // Orden de la barra en Gestor: Hoy(0), Herramientas(1), Miembros(2),
    // Novedades(3), Academia(4).
    testWidgets('en Academia se marca Academia', (tester) async {
      await montar(
        tester,
        rol: 'dueño',
        modo: AppMode.gestor,
        ruta: Routes.academia,
      );
      expect(_seleccionado(tester), 4);
    });

    testWidgets('en Equipo se sigue marcando Academia, no Hoy', (tester) async {
      await montar(
        tester,
        rol: 'dueño',
        modo: AppMode.gestor,
        ruta: Routes.equipo,
      );
      expect(_seleccionado(tester), 4);
    });

    testWidgets('en Tarifas se marca Herramientas', (tester) async {
      await montar(
        tester,
        rol: 'dueño',
        modo: AppMode.gestor,
        ruta: Routes.tarifas,
      );
      expect(_seleccionado(tester), 1);
    });

    // Cambios de escuela está congelado para v1 (ver FREEZE.md): la pestaña
    // "Cambios" del Administrador llevaba a una ruta que el router ya no
    // resuelve. Ahora el Administrador solo tiene Academias y Perfil.
    testWidgets('el Administrador ya no tiene la pestaña Cambios', (
      tester,
    ) async {
      await montar(
        tester,
        rol: 'administrador',
        modo: AppMode.entrenamiento,
        ruta: Routes.admin,
      );
      final barra = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(barra.destinations.length, 2);
      expect(find.text('Cambios'), findsNothing);
    });
  });
}
