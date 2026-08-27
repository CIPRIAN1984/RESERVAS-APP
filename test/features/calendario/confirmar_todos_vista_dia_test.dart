import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:itaca/app/app_mode.dart';
import 'package:itaca/app/theme/app_theme.dart';
import 'package:itaca/core/auth/auth_state.dart';
import 'package:itaca/core/models/profile.dart';
import 'package:itaca/features/calendario/application/clases_providers.dart';
import 'package:itaca/features/calendario/data/clase_resumen.dart';
import 'package:itaca/features/calendario/data/clases_repository.dart';
import 'package:itaca/features/calendario/presentation/calendario_screen.dart';

/// Primera fase de mejoras tras el piloto, punto 2: «Confirmar todos» vivía
/// solo dentro del detalle de cada clase. Cipri lo quiere también en la
/// vista de día, sin entrar en cada clase una por una.

class _RepoFalso implements ClasesRepository {
  final List<String> llamadas = [];

  @override
  Future<List<String>> listarAlumnosInscritos(String claseId) async {
    llamadas.add('listarAlumnosInscritos');
    return ['a1', 'a2'];
  }

  @override
  Future<void> marcarAsistenciaEnBloque({
    required String claseId,
    required List<String> alumnoIds,
    required String validadoPor,
  }) async {
    llamadas.add('marcarAsistenciaEnBloque($alumnoIds)');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ModoFijo extends AppModeNotifier {
  @override
  AppMode build() => AppMode.gestor;
}

ClaseResumen _clase({int pendientes = 3}) {
  final hoy = DateTime.now();
  final inicio = DateTime(hoy.year, hoy.month, hoy.day, 17);
  return ClaseResumen(
    id: 'c1',
    titulo: 'Iniciación no gi',
    fechaHoraInicio: inicio,
    fechaHoraFin: inicio.add(const Duration(hours: 1)),
    aforoMaximo: 40,
    profesorId: 'u1',
    profesorNombre: 'Riojano',
    inscritosCount: 3,
    pendientesConfirmar: pendientes,
  );
}

Widget _app(_RepoFalso repo, {ClaseResumen? clase}) => ProviderScope(
  overrides: [
    currentUserIdProvider.overrideWithValue('u1'),
    currentProfileProvider.overrideWith(
      (ref) async => Profile(
        id: 'u1',
        academiaId: 'a1',
        rol: 'dueño',
        nombre: 'Riojano',
        apellidos: 'Ejemplo',
        estado: 'activo',
      ),
    ),
    appModeProvider.overrideWith(_ModoFijo.new),
    clasesSemanaProvider.overrideWith((ref) async => [clase ?? _clase()]),
    clasesRepositoryProvider.overrideWithValue(repo),
  ],
  child: MaterialApp(theme: AppTheme.light, home: const CalendarioScreen()),
);

void main() {
  setUpAll(() async {
    await initializeDateFormatting('es_ES');
  });

  testWidgets('con pendientes, la tarjeta del día ofrece confirmarlos', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 900));
    await tester.pumpWidget(_app(_RepoFalso()));
    await tester.pumpAndSettle();

    expect(find.text('Confirmar 3 alumnos'), findsOneWidget);
  });

  testWidgets('sin pendientes, no aparece ningún botón de confirmar', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 900));
    await tester.pumpWidget(_app(_RepoFalso(), clase: _clase(pendientes: 0)));
    await tester.pumpAndSettle();

    expect(find.textContaining('Confirmar'), findsNothing);
  });

  testWidgets(
    'confirmar desde la tarjeta pide confirmación y no toca el detalle',
    (tester) async {
      final repo = _RepoFalso();
      await tester.binding.setSurfaceSize(const Size(412, 900));
      await tester.pumpWidget(_app(repo));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Confirmar 3 alumnos'));
      await tester.pumpAndSettle();

      // Pide confirmación antes de tocar nada, y no ha navegado al detalle.
      expect(find.text('Confirmar la clase entera'), findsOneWidget);
      expect(repo.llamadas, isEmpty);
      expect(find.text('Todavía no hay participantes.'), findsNothing);

      await tester.tap(find.text('Confirmar todos'));
      await tester.pumpAndSettle();

      expect(repo.llamadas, [
        'listarAlumnosInscritos',
        "marcarAsistenciaEnBloque([a1, a2])",
      ]);
    },
  );
}
