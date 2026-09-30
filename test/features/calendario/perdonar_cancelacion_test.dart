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
import 'package:itaca/features/calendario/domain/pasar_lista.dart';
import 'package:itaca/features/calendario/presentation/clase_detalle_screen.dart';
import 'package:itaca/features/tarifas/application/tarifas_providers.dart';
import 'package:itaca/features/tarifas/data/tarifa.dart';

/// Auditoría del 30/09/2026: no había forma de perdonar una cancelación
/// tardía ya registrada. Cipri decidió que puedan hacerlo el Dueño y el
/// Profesor, desde la propia clase.

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
  _RepoFalso(this.participantes);

  final ParticipantesClase participantes;
  final List<String> vecesLlamado = [];
  List<String>? ultimosAlumnoIds;
  final List<String> perdonados = [];

  @override
  Future<void> perdonarCancelacionTardia({
    required String claseId,
    required String alumnoId,
  }) async {
    perdonados.add('$claseId/$alumnoId');
  }

  @override
  Future<ParticipantesClase> listarParticipantes(String claseId) async =>
      participantes;

  @override
  Future<void> marcarAsistenciaEnBloque({
    required String claseId,
    required List<String> alumnoIds,
    required String validadoPor,
  }) async {
    vecesLlamado.add(claseId);
    ultimosAlumnoIds = alumnoIds;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Por defecto, una clase que empezó hace diez minutos: solo entonces se
/// puede pasar lista.
ClaseResumen _clase({Duration desdeAhora = const Duration(minutes: -10)}) {
  final inicio = DateTime.now().add(desdeAhora);
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

Widget _app(_RepoFalso repo, {ClaseResumen? clase}) => ProviderScope(
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
    home: ClaseDetalleScreen(clase: clase ?? _clase()),
  ),
);

void main() {
  setUpAll(() async {
    await initializeDateFormatting('es_ES');
  });

  _RepoFalso repoConTardia() => _RepoFalso(
    ParticipantesClase(
      inscritos: [_alumno(id: 'a1', nombre: 'Uno', validada: false)],
      listaEspera: const [],
      cancelacionesTardias: [_alumno(id: 'a2', nombre: 'Dos', validada: false)],
    ),
  );

  testWidgets('quien canceló tarde sale aparte, con el botón de perdonar', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 900));
    await tester.pumpWidget(_app(repoConTardia()));
    await tester.pumpAndSettle();

    expect(find.text('Cancelaron tarde'), findsOneWidget);
    expect(find.text('Dos Ejemplo'), findsOneWidget);
    expect(find.text('Perdonar'), findsOneWidget);
  });

  testWidgets('perdonar pide confirmación y avisa al servidor de quién es', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 900));
    final repo = repoConTardia();
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Perdonar'));
    await tester.pumpAndSettle();

    expect(find.text(textoPerdonar('Dos Ejemplo')), findsOneWidget);
    expect(repo.perdonados, isEmpty);

    await tester.tap(find.widgetWithText(FilledButton, 'Perdonar'));
    await tester.pumpAndSettle();

    expect(repo.perdonados, ['c1/a2']);
  });

  testWidgets('echarse atrás no perdona nada', (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 900));
    final repo = repoConTardia();
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Perdonar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(repo.perdonados, isEmpty);
  });

  testWidgets('sin cancelaciones tardías no aparece la sección', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 900));
    await tester.pumpWidget(
      _app(
        _RepoFalso(
          ParticipantesClase(
            inscritos: [_alumno(id: 'a1', nombre: 'Uno', validada: false)],
            listaEspera: const [],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Cancelaron tarde'), findsNothing);
    expect(find.text('Perdonar'), findsNothing);
  });
}
