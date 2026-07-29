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

import 'ayuda_golden.dart';

Profile _perfil({required String rol}) => Profile(
  id: 'u1',
  academiaId: 'a1',
  rol: rol,
  nombre: 'Alumno',
  apellidos: 'Ejemplo',
  estado: 'activo',
);

/// Contenido de relleno: aquí se prueba el armazón, no las pantallas.
class _Contenido extends StatelessWidget {
  const _Contenido(this.titulo);

  final String titulo;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: Theme.of(context).textTheme.displayLarge),
          const SizedBox(height: 8),
          Text(
            'Contenido de la pantalla',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

Widget _app(Profile perfil, AppMode modo, String rutaInicial) {
  final router = GoRouter(
    initialLocation: rutaInicial,
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
            Routes.admin,
            Routes.solicitudesCambioEscuela,
          ])
            GoRoute(path: r, builder: (_, _) => _Contenido(r)),
        ],
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      currentProfileProvider.overrideWith((ref) async => perfil),
      appModeProvider.overrideWith(() => _ModoFijo(modo)),
    ],
    child: MaterialApp.router(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: router,
    ),
  );
}

class _ModoFijo extends AppModeNotifier {
  _ModoFijo(this._inicial);
  final AppMode _inicial;
  @override
  AppMode build() => _inicial;
}

void main() {
  setUpAll(cargarTipografias);

  testWidgets('Barra inferior — modo Entrenamiento (alumno)', (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 760));
    await tester.pumpWidget(
      _app(_perfil(rol: 'alumno'), AppMode.entrenamiento, Routes.inicio),
    );
    await tester.pumpAndSettle();

    // Un alumno ve los cuatro destinos de entrenamiento y ningún botón de modo.
    expect(find.text('Inicio'), findsWidgets);
    expect(find.text('Estadísticas'), findsWidgets);
    expect(find.text('Perfil'), findsWidgets);
    expect(find.text('Cambiar a Gestor'), findsNothing);

    await comparaCon(
      find.byType(MaterialApp),
      'goldens/shell_entrenamiento.png',
    );
  });

  testWidgets('Barra inferior — modo Gestor (dueño)', (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 760));
    await tester.pumpWidget(
      _app(_perfil(rol: 'dueño'), AppMode.gestor, Routes.herramientas),
    );
    await tester.pumpAndSettle();

    expect(find.text('Herramientas'), findsWidgets);
    expect(find.text('Academia'), findsWidgets);
    // El dueño sí puede volver a entrenar.
    expect(find.text('Cambiar a Entrenamiento'), findsOneWidget);

    await comparaCon(find.byType(MaterialApp), 'goldens/shell_gestor.png');
  });

  testWidgets('El dueño en modo entrenamiento ve el botón para gestionar', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 760));
    await tester.pumpWidget(
      _app(_perfil(rol: 'dueño'), AppMode.entrenamiento, Routes.inicio),
    );
    await tester.pumpAndSettle();

    expect(find.text('Cambiar a Gestor'), findsOneWidget);
  });

  testWidgets('El administrador de plataforma no tiene modos', (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 760));
    await tester.pumpWidget(
      _app(_perfil(rol: 'administrador'), AppMode.entrenamiento, Routes.admin),
    );
    await tester.pumpAndSettle();

    expect(find.text('Academias'), findsWidgets);
    expect(find.text('Cambiar a Gestor'), findsNothing);
  });
}
