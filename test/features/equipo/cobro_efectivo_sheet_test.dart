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
import 'package:itaca/features/equipo/presentation/dar_cuota_sheet.dart';
import 'package:itaca/features/tarifas/application/tarifas_providers.dart';
import 'package:itaca/features/tarifas/data/tarifa.dart';
import 'package:itaca/shared/navigation/main_shell.dart';

/// La hoja de «Cobro en efectivo» se abría en el navegador de dentro del
/// armazón, así que la barra inferior le tapaba el pie: con cuatro tarifas,
/// «Registrar cobro» caía fuera de la pantalla y no había forma de cobrarle
/// a nadie. La hoja se veía entera menos justo el botón que hace el trabajo.

final _alumno = Profile(
  id: 'a1',
  academiaId: 'ac1',
  rol: 'alumno',
  nombre: 'Riojano',
  apellidos: 'Ejemplo',
  estado: 'activo',
);

List<Tarifa> _tarifas() => [
  for (final (id, nombre, precio) in [
    ('t1', 'corral', 80.0),
    ('t2', 'black', 70.0),
    ('t3', 'blue', 60.0),
    ('t4', 'white', 50.0),
  ])
    Tarifa(
      id: id,
      academiaId: 'ac1',
      nombre: nombre,
      precio: precio,
      periodicidad: 'mensual',
      activo: true,
    ),
];

class _ModoGestor extends AppModeNotifier {
  @override
  AppMode build() => AppMode.gestor;
}

/// Pantalla mínima que solo abre la hoja, para probarla dentro del armazón
/// real: con su barra inferior, que es lo que la tapaba.
class _Lanzadera extends StatelessWidget {
  const _Lanzadera();

  @override
  Widget build(BuildContext context) => Center(
    child: FilledButton(
      onPressed: () => mostrarDarCuota(context, _alumno),
      child: const Text('Abrir'),
    ),
  );
}

Widget _app() {
  final router = GoRouter(
    initialLocation: Routes.inicio,
    routes: [
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(path: Routes.inicio, builder: (_, _) => const _Lanzadera()),
        ],
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      currentUserIdProvider.overrideWithValue('d1'),
      currentProfileProvider.overrideWith(
        (ref) async => Profile(
          id: 'd1',
          academiaId: 'ac1',
          rol: 'dueño',
          nombre: 'Itaca',
          apellidos: 'Jiu Jitsu',
          estado: 'activo',
        ),
      ),
      appModeProvider.overrideWith(_ModoGestor.new),
      tarifasProvider(true).overrideWith((ref) async => _tarifas()),
    ],
    child: MaterialApp.router(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: router,
    ),
  );
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('es_ES');
  });

  testWidgets('«Registrar cobro» se ve entero con cuatro tarifas', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 760));
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();

    expect(find.text('Cobro en efectivo'), findsOneWidget);
    expect(find.text('corral'), findsOneWidget);

    final boton = find.widgetWithText(FilledButton, 'Registrar cobro');
    final rect = tester.getTopLeft(boton) & tester.getSize(boton);
    expect(
      rect.bottom,
      lessThanOrEqualTo(760),
      reason:
          'El botón se sale por abajo de la pantalla ($rect): es justo lo '
          'que impedía cobrar en mano.',
    );

    // Y se puede pulsar de verdad: si la barra inferior queda por encima, el
    // toque se lo lleva ella y el botón deja de ser alcanzable. Comparar
    // rectángulos no vale aquí, porque solaparse no dice quién está delante.
    expect(
      boton.hitTestable(),
      findsOneWidget,
      reason: 'Algo se ha puesto por encima y el botón ya no recibe el toque.',
    );
  });

  testWidgets('no se puede registrar sin elegir tarifa', (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 760));
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();

    final boton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Registrar cobro'),
    );
    expect(boton.onPressed, isNull);

    await tester.tap(find.text('corral'));
    await tester.pumpAndSettle();

    final activado = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Registrar cobro'),
    );
    expect(activado.onPressed, isNotNull);
  });
}
