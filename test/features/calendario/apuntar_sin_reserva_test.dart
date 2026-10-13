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
import 'package:itaca/features/calendario/presentation/apuntar_sin_reserva_sheet.dart';
import 'package:itaca/features/calendario/presentation/clase_detalle_screen.dart';
import 'package:itaca/features/miembros/application/miembros_providers.dart';
import 'package:itaca/features/tarifas/application/tarifas_providers.dart';
import 'package:itaca/features/tarifas/data/tarifa.dart';

/// Decisión de Cipri (09/10/2026): quien llega a clase sin reserva lo
/// apunta el Dueño o el Profesor desde la clase. Antes no había forma: ni
/// reservar por él, ni pasarle lista.

Profile _miembro(
  String id,
  String nombre, {
  String estado = 'activo',
  bool entrena = true,
}) => Profile(
  id: id,
  academiaId: 'ac1',
  rol: 'alumno',
  nombre: nombre,
  apellidos: 'Ejemplo',
  estado: estado,
  entrena: entrena,
);

class _RepoFalso implements ClasesRepository {
  final List<String> apuntados = [];
  Object? error;

  @override
  Future<ParticipantesClase> listarParticipantes(String claseId) async =>
      const ParticipantesClase(
        inscritos: [
          InscritoAlumno(
            alumnoId: 'a1',
            nombre: 'Reservó',
            apellidos: 'Ejemplo',
            asistenciaValidada: false,
          ),
        ],
        listaEspera: [],
      );

  @override
  Future<void> apuntarEnClase({
    required String claseId,
    required String alumnoId,
  }) async {
    if (error != null) throw error!;
    apuntados.add(alumnoId);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ClaseResumen _clase(DateTime inicio) => ClaseResumen(
  id: 'c1',
  titulo: 'BJJ',
  fechaHoraInicio: inicio,
  fechaHoraFin: inicio.add(const Duration(hours: 1)),
  aforoMaximo: 20,
  profesorId: 'd1',
  profesorNombre: 'Itaca',
  inscritosCount: 1,
);

Widget _app(_RepoFalso repo, ClaseResumen clase) => ProviderScope(
  overrides: [
    currentUserIdProvider.overrideWithValue('d1'),
    currentProfileProvider.overrideWith(
      (ref) async => Profile(
        id: 'd1',
        academiaId: 'ac1',
        rol: 'profesor',
        nombre: 'Profe',
        estado: 'activo',
      ),
    ),
    clasesRepositoryProvider.overrideWithValue(repo),
    tarifasProvider(true).overrideWith((ref) async => const <Tarifa>[]),
    alumnosMiembrosProvider.overrideWith(
      (ref) async => [
        _miembro('a1', 'Reservó'),
        _miembro('a2', 'Llegado'),
        _miembro('a3', 'Debaja', estado: 'baja'),
        _miembro('a4', 'Tutor', entrena: false),
      ],
    ),
  ],
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light,
    home: ClaseDetalleScreen(clase: clase),
  ),
);

void main() {
  setUpAll(() => initializeDateFormatting('es_ES'));

  testWidgets('con la clase empezada, se apunta a quien ha venido', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 900));
    final repo = _RepoFalso();
    await tester.pumpWidget(
      _app(repo, _clase(DateTime.now().subtract(const Duration(minutes: 5)))),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Apuntar a alguien que ha venido'));
    await tester.pumpAndSettle();

    // Solo quien puede venir: ni el que ya reservó, ni el de baja, ni el
    // tutor que no entrena.
    expect(find.text('Llegado Ejemplo'), findsOneWidget);
    expect(find.text('Debaja Ejemplo'), findsNothing);
    expect(find.text('Tutor Ejemplo'), findsNothing);

    await tester.tap(find.text('Llegado Ejemplo'));
    await tester.pumpAndSettle();

    expect(repo.apuntados, ['a2']);
    expect(
      find.text('Llegado Ejemplo, apuntado y con la asistencia confirmada.'),
      findsOneWidget,
    );
  });

  testWidgets('si el servidor dice que no, se explica por qué', (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 900));
    final repo = _RepoFalso()
      ..error = Exception(
        'P0001: No le quedan clases en su tarifa. Cóbrale una clase extra '
        'antes de apuntarlo.',
      );
    await tester.pumpWidget(
      _app(repo, _clase(DateTime.now().subtract(const Duration(minutes: 5)))),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Apuntar a alguien que ha venido'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Llegado Ejemplo'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'No le quedan clases en su tarifa. Cóbrale una clase extra antes de '
        'apuntarlo.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('con la clase de mañana, todavía no se ofrece', (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 900));
    await tester.pumpWidget(
      _app(_RepoFalso(), _clase(DateTime.now().add(const Duration(days: 1)))),
    );
    await tester.pumpAndSettle();

    expect(find.text('Apuntar a alguien que ha venido'), findsNothing);
  });

  test('busca por nombre sin distinguir mayúsculas', () {
    final candidatos = candidatosSinReserva(
      [_miembro('a1', 'Nico'), _miembro('a2', 'Lucía')],
      yaEnClase: const {},
      busqueda: 'LUC',
    );
    expect(candidatos.map((c) => c.id), ['a2']);
  });
}
