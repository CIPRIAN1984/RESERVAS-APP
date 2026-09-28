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

/// Pasar lista alumno por alumno era media hora perdida en clases de 20-40
/// personas. Un solo botón confirma a todos los que aún no tienen la
/// asistencia validada — es lo que pidió Cipri, «un botón para confirmar a
/// todos los apuntados de golpe», con una confirmación antes por si acaso.
///
/// Desde la auditoría del 23/09/2026 solo se puede con la clase a punto de
/// empezar (media hora antes) o ya empezada: antes, marcaba presente a gente
/// que aún no había venido.

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

  testWidgets('con alguien sin validar, aparece el botón con el recuento', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 900));
    final repo = _RepoFalso(
      ParticipantesClase(
        inscritos: [
          _alumno(id: 'a1', nombre: 'Uno', validada: true),
          _alumno(id: 'a2', nombre: 'Dos', validada: false),
          _alumno(id: 'a3', nombre: 'Tres', validada: false),
        ],
        listaEspera: const [],
      ),
    );
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    expect(find.text('Confirmar los 2 que faltan'), findsOneWidget);
  });

  testWidgets('si ya están todos validados, no aparece el botón', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 900));
    final repo = _RepoFalso(
      ParticipantesClase(
        inscritos: [_alumno(id: 'a1', nombre: 'Uno', validada: true)],
        listaEspera: const [],
      ),
    );
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    expect(find.textContaining('Confirmar'), findsNothing);
  });

  testWidgets('confirmar llama al servidor solo con los pendientes', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 900));
    final repo = _RepoFalso(
      ParticipantesClase(
        inscritos: [
          _alumno(id: 'a1', nombre: 'Uno', validada: true),
          _alumno(id: 'a2', nombre: 'Dos', validada: false),
        ],
        listaEspera: const [],
      ),
    );
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Confirmar al que falta'));
    await tester.pumpAndSettle();

    // Pide confirmación antes de tocar nada.
    expect(find.text('Confirmar la clase entera'), findsOneWidget);
    expect(repo.vecesLlamado, isEmpty);

    await tester.tap(find.text('Confirmar todos'));
    await tester.pumpAndSettle();

    expect(repo.vecesLlamado, ['c1']);
    // Al ya validado no se le vuelve a tocar.
    expect(repo.ultimosAlumnoIds, ['a2']);
  });

  testWidgets('cancelar el aviso no llama a nada', (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 900));
    final repo = _RepoFalso(
      ParticipantesClase(
        inscritos: [_alumno(id: 'a1', nombre: 'Uno', validada: false)],
        listaEspera: const [],
      ),
    );
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Confirmar todos'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(repo.vecesLlamado, isEmpty);
  });

  testWidgets('con la clase de mañana no se puede pasar lista todavía', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 900));
    final repo = _RepoFalso(
      ParticipantesClase(
        inscritos: [
          _alumno(id: 'a1', nombre: 'Uno', validada: false),
          _alumno(id: 'a2', nombre: 'Dos', validada: false),
        ],
        listaEspera: const [],
      ),
    );
    await tester.pumpWidget(
      _app(repo, clase: _clase(desdeAhora: const Duration(days: 1))),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Confirmar'), findsNothing);
    expect(find.text('Validar'), findsNothing);
    expect(
      find.text('Podrás pasar lista media hora antes de que empiece.'),
      findsOneWidget,
    );
  });

  testWidgets('a veinte minutos de empezar, ya se puede', (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 900));
    final repo = _RepoFalso(
      ParticipantesClase(
        inscritos: [_alumno(id: 'a1', nombre: 'Uno', validada: false)],
        listaEspera: const [],
      ),
    );
    await tester.pumpWidget(
      _app(repo, clase: _clase(desdeAhora: const Duration(minutes: 20))),
    );
    await tester.pumpAndSettle();

    expect(find.text('Confirmar todos'), findsOneWidget);
    expect(find.text('Validar'), findsOneWidget);
    expect(find.textContaining('Podrás pasar lista'), findsNothing);
  });

  testWidgets('el aviso dice que confirmar solo si han venido todos', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 900));
    final repo = _RepoFalso(
      ParticipantesClase(
        inscritos: [
          _alumno(id: 'a1', nombre: 'Uno', validada: false),
          _alumno(id: 'a2', nombre: 'Dos', validada: false),
        ],
        listaEspera: const [],
      ),
    );
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Confirmar todos'));
    await tester.pumpAndSettle();

    expect(find.text(avisoConfirmarTodos(2)), findsOneWidget);
    expect(find.textContaining('solo si han venido todos'), findsOneWidget);
  });
}
