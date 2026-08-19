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
import 'package:itaca/features/calendario/data/inscrito_alumno.dart';
import 'package:itaca/features/calendario/presentation/clase_detalle_screen.dart';
import 'package:itaca/features/tarifas/application/tarifas_providers.dart';
import 'package:itaca/features/tarifas/data/tarifa.dart';

/// «Puede que le doy a confirmar a todos y me doy cuenta que a uno no
/// quiero confirmarlo, quiero tener la opción» — Cipri, tras probar
/// «confirmar todos». La marca verde de un alumno ya validado pasa a ser
/// tocable: deshace justo esa asistencia, no las demás.

InscritoAlumno _alumno({
  required String id,
  required String nombre,
  required bool validada,
}) => InscritoAlumno(
  alumnoId: id,
  nombre: nombre,
  apellidos: 'Ejemplo',
  cinturon: 'azul',
  asistenciaValidada: validada,
  sinCuota: false,
);

class _RepoFalso implements ClasesRepository {
  _RepoFalso(this._inscritos);

  List<InscritoAlumno> _inscritos;
  final List<String> deshechos = [];

  @override
  Future<ParticipantesClase> listarParticipantes(String claseId) async =>
      ParticipantesClase(inscritos: _inscritos, listaEspera: const []);

  @override
  Future<void> deshacerAsistencia({
    required String claseId,
    required String alumnoId,
  }) async {
    deshechos.add(alumnoId);
    _inscritos = [
      for (final a in _inscritos)
        if (a.alumnoId == alumnoId)
          _alumno(id: a.alumnoId, nombre: a.nombre, validada: false)
        else
          a,
    ];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ClaseResumen _clase() {
  final inicio = DateTime.now().add(const Duration(days: 1));
  return ClaseResumen(
    id: 'c1',
    titulo: 'Iniciación no gi',
    fechaHoraInicio: inicio,
    fechaHoraFin: inicio.add(const Duration(hours: 1)),
    aforoMaximo: 20,
    profesorId: 'd1',
    profesorNombre: 'Itaca',
    inscritosCount: 2,
  );
}

Widget _app(_RepoFalso repo) => ProviderScope(
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
    home: ClaseDetalleScreen(clase: _clase()),
  ),
);

void main() {
  setUpAll(() async {
    await initializeDateFormatting('es_ES');
  });

  testWidgets('tocar la marca verde deshace justo esa asistencia', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 900));
    final repo = _RepoFalso([
      _alumno(id: 'a1', nombre: 'Uno', validada: true),
      _alumno(id: 'a2', nombre: 'Dos', validada: true),
    ]);
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Deshacer confirmación'), findsNWidgets(2));

    await tester.tap(find.byTooltip('Deshacer confirmación').first);
    await tester.pumpAndSettle();

    expect(repo.deshechos, ['a1']);
    // Al de al lado no se le toca: sigue con su marca, y a Uno le vuelve a
    // salir el botón de validar en vez de la marca.
    expect(find.byTooltip('Deshacer confirmación'), findsOneWidget);
    expect(find.text('Validar'), findsOneWidget);
  });

  testWidgets('sin validar todavía, no hay nada que deshacer', (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 900));
    final repo = _RepoFalso([
      _alumno(id: 'a1', nombre: 'Uno', validada: false),
    ]);
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Deshacer confirmación'), findsNothing);
    expect(find.text('Validar'), findsOneWidget);
  });
}
