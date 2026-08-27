import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:itaca/app/theme/app_theme.dart';
import 'package:itaca/core/auth/auth_state.dart';
import 'package:itaca/core/models/profile.dart';
import 'package:itaca/features/calendario/application/clases_providers.dart';
import 'package:itaca/features/calendario/data/clase_resumen.dart';
import 'package:itaca/features/calendario/data/clases_repository.dart';
import 'package:itaca/features/calendario/presentation/clase_detalle_screen.dart';
import 'package:itaca/features/tarifas/application/tarifas_providers.dart';
import 'package:itaca/features/tarifas/data/tarifa.dart';

/// El dueño no tenía forma de editar, cerrar o cancelar una clase ya
/// publicada — primera fase de mejoras tras el piloto, punto 1.

class _RepoFalso implements ClasesRepository {
  _RepoFalso({this.estadoTrasRecargar = 'cerrada'});

  final String estadoTrasRecargar;
  final List<String> llamadas = [];
  bool cerrarPedido = false;

  @override
  Future<ParticipantesClase> listarParticipantes(String claseId) async =>
      const ParticipantesClase(inscritos: [], listaEspera: []);

  @override
  Future<Map<String, dynamic>> obtenerClase(String claseId) async {
    llamadas.add('obtenerClase');
    return {
      'titulo': 'Iniciación no gi',
      'descripcion': null,
      'fecha_hora_inicio': DateTime.now()
          .add(const Duration(days: 1))
          .toUtc()
          .toIso8601String(),
      'fecha_hora_fin': DateTime.now()
          .add(const Duration(days: 1, hours: 1))
          .toUtc()
          .toIso8601String(),
      'aforo_maximo': 20,
      'estado': estadoTrasRecargar,
    };
  }

  @override
  Future<void> cambiarEstadoClase({
    required String claseId,
    required bool cerrar,
  }) async {
    llamadas.add('cambiarEstadoClase($cerrar)');
    cerrarPedido = cerrar;
  }

  @override
  Future<int> cancelarClase(String claseId) async {
    llamadas.add('cancelarClase');
    return 3;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ClaseResumen _clase({String estado = 'activa'}) {
  final inicio = DateTime.now().add(const Duration(days: 1));
  return ClaseResumen(
    id: 'c1',
    titulo: 'Iniciación no gi',
    fechaHoraInicio: inicio,
    fechaHoraFin: inicio.add(const Duration(hours: 1)),
    aforoMaximo: 20,
    profesorId: 'd1',
    profesorNombre: 'Itaca',
    inscritosCount: 0,
    estado: estado,
  );
}

Widget _app(
  _RepoFalso repo, {
  String estadoInicial = 'activa',
}) => ProviderScope(
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
    clasesRepositoryProvider.overrideWithValue(repo),
    tarifasProvider(true).overrideWith((ref) async => const <Tarifa>[]),
  ],
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light,
    // La pantalla real siempre se abre empujada sobre otra: aquí igual, para
    // que Navigator.pop() al cancelar tenga a dónde volver.
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    ClaseDetalleScreen(clase: _clase(estado: estadoInicial)),
              ),
            ),
            child: const Text('Abrir clase'),
          ),
        ),
      ),
    ),
  ),
);

void main() {
  setUpAll(() async {
    await initializeDateFormatting('es_ES');
  });

  Future<void> abrirDetalle(WidgetTester tester, Widget app) async {
    await tester.binding.setSurfaceSize(const Size(412, 900));
    await tester.pumpWidget(app);
    await tester.tap(find.text('Abrir clase'));
    await tester.pumpAndSettle();
  }

  testWidgets('el menú de gestión ofrece editar, cerrar y cancelar', (
    tester,
  ) async {
    await abrirDetalle(tester, _app(_RepoFalso()));

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    expect(find.text('Editar clase'), findsOneWidget);
    expect(find.text('Cerrar a nuevas reservas'), findsOneWidget);
    expect(find.text('Cancelar la clase'), findsOneWidget);
  });

  testWidgets('una clase cancelada ya no ofrece el menú de gestión', (
    tester,
  ) async {
    await abrirDetalle(tester, _app(_RepoFalso(), estadoInicial: 'cancelada'));

    expect(find.byIcon(Icons.more_vert), findsNothing);
  });

  testWidgets('cerrar la clase avisa al servidor y actualiza el estado', (
    tester,
  ) async {
    final repo = _RepoFalso(estadoTrasRecargar: 'cerrada');
    await abrirDetalle(tester, _app(repo));

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cerrar a nuevas reservas'));
    await tester.pumpAndSettle();

    expect(repo.llamadas, ['cambiarEstadoClase(true)', 'obtenerClase']);
    // PastillaEstado pone el texto en mayúsculas (diseño I+, tipografía mono).
    expect(find.text('CERRADA A NUEVAS RESERVAS'), findsOneWidget);
  });

  testWidgets('cancelar pide confirmación antes de tocar nada', (tester) async {
    final repo = _RepoFalso();
    await abrirDetalle(tester, _app(repo));

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar la clase'));
    await tester.pumpAndSettle();

    expect(find.text('¿Cancelar esta clase?'), findsOneWidget);
    expect(repo.llamadas, isEmpty);

    await tester.tap(find.text('Volver'));
    await tester.pumpAndSettle();
    expect(repo.llamadas, isEmpty);
  });

  testWidgets(
    'confirmar la cancelación llama al servidor, avisa cuántos y vuelve atrás',
    (tester) async {
      final repo = _RepoFalso();
      await abrirDetalle(tester, _app(repo));
      expect(find.text('Abrir clase'), findsNothing);

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar la clase'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar la clase'));
      await tester.pumpAndSettle();

      expect(repo.llamadas, ['cancelarClase']);
      // Vuelve a la pantalla anterior.
      expect(find.text('Abrir clase'), findsOneWidget);
      expect(
        find.text('Clase cancelada. Se ha avisado a 3 alumnos.'),
        findsOneWidget,
      );
    },
  );
}
