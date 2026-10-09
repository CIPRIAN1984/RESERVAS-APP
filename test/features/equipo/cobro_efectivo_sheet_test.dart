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
import 'package:itaca/features/equipo/application/equipo_providers.dart';
import 'package:itaca/features/equipo/data/equipo_repository.dart';
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

/// Las de producción que no son mensuales (09/10/2026).
List<Tarifa> _tarifasNoMensuales() => [
  const Tarifa(
    id: 'tb',
    academiaId: 'ac1',
    nombre: 'bono 10 sesiones',
    precio: 80,
    periodicidad: 'trimestral',
    activo: true,
    clasesIncluidas: 10,
  ),
  const Tarifa(
    id: 'ts',
    academiaId: 'ac1',
    nombre: 'dia suelto',
    precio: 10,
    periodicidad: 'suelta',
    activo: true,
    clasesIncluidas: 1,
  ),
];

/// Apunta lo que se le pide al servidor, sin llamarlo.
class _RepoFalso implements EquipoRepository {
  double? importe;
  String? tarifaId;
  int? meses;
  final List<String> claves = [];

  /// Cuántas veces más falla, como si se cortara la conexión.
  int fallos = 0;

  @override
  Future<void> activarCuotaEfectivo({
    required String alumnoId,
    required String tarifaId,
    required int meses,
    required double importe,
    required String clave,
  }) async {
    claves.add(clave);
    if (fallos > 0) {
      fallos--;
      throw Exception('Se ha cortado la conexión');
    }
    this.importe = importe;
    this.tarifaId = tarifaId;
    this.meses = meses;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

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

Widget _app([
  _RepoFalso? repo,
  ({DateTime fin, bool renovacionPendiente})? enVigor,
  List<Tarifa> Function() tarifas = _tarifas,
]) {
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
      tarifasProvider(true).overrideWith((ref) async => tarifas()),
      if (repo != null) equipoRepositoryProvider.overrideWithValue(repo),
      cuotaEnVigorProvider('a1').overrideWith((ref) async => enVigor),
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

  // Auditoría del 30/09/2026: activar una cuota no dejaba constancia de
  // cuánto dinero se había recibido.
  group('importe recibido', () {
    Future<_RepoFalso> abrir(WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(412, 900));
      final repo = _RepoFalso();
      await tester.pumpWidget(_app(repo));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
      return repo;
    }

    String importe(WidgetTester tester) =>
        tester.widget<TextField>(find.byType(TextField)).controller!.text;

    testWidgets('propone el precio de la tarifa por los meses', (tester) async {
      await abrir(tester);
      await tester.tap(find.text('white'));
      await tester.pumpAndSettle();
      expect(importe(tester), '50,00');

      await tester.tap(find.text('3 meses'));
      await tester.pumpAndSettle();
      expect(importe(tester), '150,00');
    });

    testWidgets('con descuento se registra lo que se escribe, no el precio', (
      tester,
    ) async {
      final repo = await abrir(tester);
      await tester.tap(find.text('white'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '45,50');
      await tester.pumpAndSettle();
      // Cambiar de meses ya no pisa lo que ha escrito el Dueño.
      await tester.tap(find.text('3 meses'));
      await tester.pumpAndSettle();
      expect(importe(tester), '45,50');

      await tester.ensureVisible(
        find.widgetWithText(FilledButton, 'Registrar cobro'),
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Registrar cobro'));
      await tester.pumpAndSettle();

      expect(repo.tarifaId, 't4');
      expect(repo.importe, 45.5);
    });

    testWidgets('un importe que no es un número no deja registrar', (
      tester,
    ) async {
      await abrir(tester);
      await tester.tap(find.text('white'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'cincuenta');
      await tester.pumpAndSettle();

      expect(
        find.text('Escribe un importe, por ejemplo 50 o 45,50.'),
        findsOneWidget,
      );
      final boton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Registrar cobro'),
      );
      expect(boton.onPressed, isNull);
    });
  });

  // Decisión de Cipri (30/09/2026): renovar con la cuota en vigor no pierde
  // días; la nueva empieza cuando acaba la actual.
  group('renovar antes de que acabe', () {
    Future<_RepoFalso> abrir(
      WidgetTester tester, {
      bool renovacionPendiente = false,
    }) async {
      await tester.binding.setSurfaceSize(const Size(412, 900));
      final repo = _RepoFalso();
      await tester.pumpWidget(
        _app(repo, (
          fin: DateTime(2030, 10, 15, 12),
          renovacionPendiente: renovacionPendiente,
        )),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('white'));
      await tester.pumpAndSettle();
      return repo;
    }

    testWidgets('dice que empieza cuando acaba la actual, y hasta cuándo', (
      tester,
    ) async {
      await abrir(tester);

      expect(
        find.text(
          'Empieza cuando acabe la cuota actual, el 15 de octubre de 2030, '
          'y podrá reservar hasta el 15 de noviembre de 2030.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('manda los meses al servidor, no una fecha contada desde hoy', (
      tester,
    ) async {
      final repo = await abrir(tester);
      await tester.tap(find.text('3 meses'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.widgetWithText(FilledButton, 'Registrar cobro'),
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Registrar cobro'));
      await tester.pumpAndSettle();

      expect(repo.meses, 3);
    });

    testWidgets('con una renovación ya esperando, no deja registrar otra', (
      tester,
    ) async {
      await abrir(tester, renovacionPendiente: true);

      expect(
        find.textContaining('Ya tiene una renovación pagada'),
        findsOneWidget,
      );
      final boton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Registrar cobro'),
      );
      expect(boton.onPressed, isNull);
    });
  });

  // Auditoría del 09/10/2026: la hoja trataba todas las tarifas como
  // mensuales y el bono trimestral de 80 € cobrado «3 meses» proponía 240 €.
  group('cada tarifa se cobra por sus periodos', () {
    Future<_RepoFalso> abrir(WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(412, 900));
      final repo = _RepoFalso();
      await tester.pumpWidget(_app(repo, null, _tarifasNoMensuales));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
      return repo;
    }

    String importe(WidgetTester tester) =>
        tester.widget<TextField>(find.byType(TextField)).controller!.text;

    Future<void> registrar(WidgetTester tester) async {
      await tester.ensureVisible(
        find.widgetWithText(FilledButton, 'Registrar cobro'),
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Registrar cobro'));
      await tester.pumpAndSettle();
    }

    testWidgets('el bono trimestral se cobra por trimestres, a su precio', (
      tester,
    ) async {
      final repo = await abrir(tester);
      await tester.tap(find.text('bono 10 sesiones'));
      await tester.pumpAndSettle();

      expect(find.text('1 mes'), findsNothing);
      expect(find.text('1 trimestre'), findsOneWidget);
      expect(importe(tester), '80,00');

      await tester.tap(find.text('2 trimestres'));
      await tester.pumpAndSettle();
      expect(importe(tester), '160,00');

      await registrar(tester);
      expect(repo.meses, 6);
      expect(repo.importe, 160);
    });

    testWidgets('dice cuántas clases da por trimestre, no al mes', (
      tester,
    ) async {
      await abrir(tester);
      expect(find.textContaining('10 clases al trimestre'), findsOneWidget);
      expect(find.textContaining('al mes'), findsNothing);
    });

    testWidgets('la suelta es una clase, sin elegir meses', (tester) async {
      final repo = await abrir(tester);
      await tester.tap(find.text('dia suelto'));
      await tester.pumpAndSettle();

      expect(find.byType(SegmentedButton<int>), findsNothing);
      expect(find.text('1 clase'), findsOneWidget);
      expect(importe(tester), '10,00');

      await registrar(tester);
      expect(repo.meses, 1);
    });

    testWidgets('reintentar tras un corte manda la misma clave', (
      tester,
    ) async {
      final repo = await abrir(tester);
      repo.fallos = 1;
      await tester.tap(find.text('bono 10 sesiones'));
      await tester.pumpAndSettle();

      await registrar(tester);
      // Falló: la hoja sigue abierta para volver a intentarlo.
      expect(find.text('Cobro en efectivo'), findsOneWidget);
      await tester.pumpAndSettle(const Duration(seconds: 5));

      await registrar(tester);
      expect(repo.claves, hasLength(2));
      expect(
        repo.claves.toSet(),
        hasLength(1),
        reason:
            'Si el primer intento llegó a guardarse, solo una clave igual '
            'evita que el servidor apunte el cobro dos veces.',
      );
    });
  });

  // Auditoría del 09/10/2026, punto 3, y decisión de Cipri: la suelta con
  // la cuota en vigor es una clase extra que se usa ya, no una renovación.
  group('clase extra', () {
    Future<_RepoFalso> abrir(
      WidgetTester tester, {
      bool renovacionPendiente = false,
    }) async {
      await tester.binding.setSurfaceSize(const Size(412, 900));
      final repo = _RepoFalso();
      await tester.pumpWidget(
        _app(repo, (
          fin: DateTime(2030, 10, 15, 12),
          renovacionPendiente: renovacionPendiente,
        ), _tarifasNoMensuales),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('dia suelto'));
      await tester.pumpAndSettle();
      return repo;
    }

    testWidgets('dice que se suma a la cuota y se usa ya', (tester) async {
      await abrir(tester);
      expect(
        find.text(
          'Se suma a su cuota actual como clase extra: puede usarla ya, '
          'hasta que acabe la cuota el 15 de octubre de 2030.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('Empieza cuando acabe'), findsNothing);
    });

    testWidgets('una renovación ya esperando no impide cobrar la extra', (
      tester,
    ) async {
      await abrir(tester, renovacionPendiente: true);
      expect(find.textContaining('Ya tiene una renovación'), findsNothing);
      final boton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Registrar cobro'),
      );
      expect(boton.onPressed, isNotNull);
    });

    testWidgets('el bono trimestral sí sigue bloqueado por la renovación', (
      tester,
    ) async {
      await abrir(tester, renovacionPendiente: true);
      await tester.tap(find.text('bono 10 sesiones'));
      await tester.pumpAndSettle();
      final boton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Registrar cobro'),
      );
      expect(boton.onPressed, isNull);
    });
  });

  test('los rechazos del servidor se explican al Dueño', () {
    expect(
      mensajeCobro(
        Exception('Su cuota ya tiene clases ilimitadas: no le hace falta'),
      ),
      contains('ilimitadas'),
    );
    expect(
      mensajeCobro(Exception('Tiene la cuota pausada: mientras lo esté')),
      contains('Reanúdala'),
    );
    expect(
      mensajeCobro(Exception('algo raro')),
      'No se ha podido registrar la cuota.',
    );
  });
}
