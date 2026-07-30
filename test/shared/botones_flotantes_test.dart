import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:itaca/app/app_mode.dart';
import 'package:itaca/app/routes.dart';
import 'package:itaca/app/theme/app_theme.dart';
import 'package:itaca/core/auth/auth_state.dart';
import 'package:itaca/core/models/profile.dart';
import 'package:itaca/features/calendario/application/clases_providers.dart';
import 'package:itaca/features/calendario/data/clase_resumen.dart';
import 'package:itaca/features/calendario/presentation/calendario_screen.dart';
import 'package:itaca/features/calendario/presentation/clase_card.dart';
import 'package:itaca/features/perfil/presentation/perfil_screen.dart';
import 'package:itaca/shared/navigation/main_shell.dart';

/// El cambio de modo iba en un botón flotante en mitad de la pantalla y tapaba
/// cosas que hay que poder pulsar: «Reservar plaza», la última fila de Perfil
/// y el propio botón «Crear clase» de la pantalla. En un móvil de 412 px los
/// dos botones flotantes no caben uno al lado del otro, así que el de modo
/// bajó a la barra inferior.
///
/// Aquí no se comprueba que los botones existan, sino que **no se pisan**: se
/// comparan los rectángulos del botón entero (no los de su texto, que son más
/// pequeños y dejan pasar el fallo) con los de lo que hay debajo.

Profile _perfil({required String rol}) => Profile(
  id: 'u1',
  academiaId: 'a1',
  rol: rol,
  nombre: 'Riojano',
  apellidos: 'Ejemplo',
  estado: 'activo',
);

/// Varias clases para que la lista llegue hasta abajo: con una sola, la
/// tarjeta se queda arriba y nada la tapa nunca.
List<ClaseResumen> _clases() {
  final hoy = DateTime.now();
  return [
    for (var i = 0; i < 6; i++)
      ClaseResumen(
        id: 'c$i',
        titulo: 'Iniciación no gi',
        fechaHoraInicio: DateTime(hoy.year, hoy.month, hoy.day, 9 + i),
        fechaHoraFin: DateTime(hoy.year, hoy.month, hoy.day, 10 + i),
        aforoMaximo: 40,
        profesorId: 'u1',
        profesorNombre: 'Riojano',
        inscritosCount: 0,
      ),
  ];
}

class _ModoFijo extends AppModeNotifier {
  _ModoFijo(this._inicial);
  final AppMode _inicial;
  @override
  AppMode build() => _inicial;
}

Widget _app({required AppMode modo, required String rutaInicial}) {
  final router = GoRouter(
    initialLocation: rutaInicial,
    routes: [
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: Routes.inicio,
            builder: (_, _) => const CalendarioScreen(),
          ),
          GoRoute(path: Routes.perfil, builder: (_, _) => const PerfilScreen()),
        ],
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      currentUserIdProvider.overrideWithValue('u1'),
      currentProfileProvider.overrideWith((ref) async => _perfil(rol: 'dueño')),
      currentAcademiaProvider.overrideWith((ref) async => null),
      appModeProvider.overrideWith(() => _ModoFijo(modo)),
      clasesMesProvider.overrideWith((ref) async => _clases()),
    ],
    child: MaterialApp.router(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: router,
    ),
  );
}

/// Rectángulo que ocupa en pantalla lo que encuentre [finder].
Rect _rect(WidgetTester tester, Finder finder) =>
    tester.getTopLeft(finder) & tester.getSize(finder);

/// El botón flotante entero, no solo su texto.
Rect _flotante(WidgetTester tester, String etiqueta) => _rect(
  tester,
  find.ancestor(
    of: find.text(etiqueta),
    matching: find.byType(FloatingActionButton),
  ),
);

void _noSePisan(Rect boton, Rect tapado, String queEs) {
  expect(
    boton.overlaps(tapado),
    isFalse,
    reason:
        'El botón flotante ($boton) vuelve a tapar $queEs ($tapado): '
        'no se puede pulsar.',
  );
}

/// Arrastra hasta el final de lo que se pueda desplazar.
Future<void> _hastaElFondo(WidgetTester tester, Finder scrollable) async {
  await tester.drag(scrollable, const Offset(0, -2000));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('es_ES');
  });

  testWidgets('el cambio de modo ya no flota sobre el contenido', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 760));
    await tester.pumpWidget(
      _app(modo: AppMode.entrenamiento, rutaInicial: Routes.inicio),
    );
    await tester.pumpAndSettle();

    // Está, pero en la barra: es un destino más, no un botón encima de todo.
    expect(find.text('Gestor'), findsOneWidget);
    expect(
      find.byType(FloatingActionButton),
      findsNothing,
      reason:
          'En Entrenamiento no hay ninguna acción flotante: si vuelve una, '
          'volverá a tapar «Reservar plaza».',
    );
  });

  testWidgets('desde la barra se salta de un modo al otro', (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 760));
    await tester.pumpWidget(
      _app(modo: AppMode.entrenamiento, rutaInicial: Routes.inicio),
    );
    await tester.pumpAndSettle();

    expect(find.text('Reservar plaza'), findsWidgets);

    await tester.tap(find.text('Gestor'));
    await tester.pumpAndSettle();

    // Ahora gestiona: aparece «Crear clase» y ya no se apunta a nada.
    expect(find.text('Crear clase'), findsOneWidget);
    expect(find.text('Reservar plaza'), findsNothing);
    // Y el sitio de la barra ofrece el camino de vuelta.
    expect(find.text('Entrenar'), findsOneWidget);
  });

  testWidgets('«Crear clase» no tapa la última clase de la lista', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 760));
    await tester.pumpWidget(
      _app(modo: AppMode.gestor, rutaInicial: Routes.inicio),
    );
    await tester.pumpAndSettle();

    await _hastaElFondo(tester, find.byType(ListView));

    final boton = _flotante(tester, 'Crear clase');
    // La tarjeta entera, no su título: el título va arriba a la izquierda y
    // nunca llega a donde está el botón, así que compararlo no prueba nada.
    final tarjetas = find.byType(ClaseCard).evaluate().toList();
    final ultima = _rect(tester, find.byWidget(tarjetas.last.widget));
    _noSePisan(boton, ultima, 'la última clase del día');
  });

  testWidgets('nada flotante tapa el final de Perfil', (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 760));
    await tester.pumpWidget(
      _app(modo: AppMode.entrenamiento, rutaInicial: Routes.perfil),
    );
    await tester.pumpAndSettle();

    await _hastaElFondo(tester, find.byType(SingleChildScrollView));

    // Las dos últimas filas quedan enteras dentro de la zona visible.
    for (final etiqueta in [
      'Privacidad y protección de datos',
      'Cerrar sesión',
    ]) {
      final fila = _rect(
        tester,
        find.ancestor(
          of: find.text(etiqueta),
          matching: find.byType(TextButton),
        ),
      );
      expect(
        fila.bottom,
        lessThanOrEqualTo(760),
        reason: '«$etiqueta» se sale de la pantalla y no se puede pulsar.',
      );
    }
  });
}
