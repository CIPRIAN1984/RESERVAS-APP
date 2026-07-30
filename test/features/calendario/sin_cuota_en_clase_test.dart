import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:itaca/app/theme/app_theme.dart';
import 'package:itaca/app/theme/color_tokens.dart';
import 'package:itaca/core/auth/auth_state.dart';
import 'package:itaca/core/models/profile.dart';
import 'package:itaca/features/calendario/application/clases_providers.dart';
import 'package:itaca/features/calendario/data/clase_resumen.dart';
import 'package:itaca/features/calendario/data/clases_repository.dart';
import 'package:itaca/features/calendario/data/inscrito_alumno.dart';
import 'package:itaca/features/calendario/presentation/clase_detalle_screen.dart';
import 'package:itaca/features/tarifas/application/tarifas_providers.dart';
import 'package:itaca/features/tarifas/data/tarifa.dart';
import 'package:itaca/shared/widgets/pantalla.dart';

/// Cipri quiere que la gente pueda apuntarse a clase sin haber pagado y verlo
/// marcado en la lista, para cobrarles en mano cuando aparezcan por el
/// gimnasio. Aquí se fija que la marca se ve y que no se le cuelga a quien sí
/// ha pagado, que sería acusar de moroso a un cliente al corriente.

InscritoAlumno _alumno({
  required String id,
  required String nombre,
  required bool sinCuota,
}) => InscritoAlumno(
  alumnoId: id,
  nombre: nombre,
  apellidos: 'Ejemplo',
  cinturon: 'azul',
  asistenciaValidada: false,
  sinCuota: sinCuota,
);

class _RepoFalso implements ClasesRepository {
  _RepoFalso(this.participantes);

  final ParticipantesClase participantes;

  @override
  Future<ParticipantesClase> listarParticipantes(String claseId) async =>
      participantes;

  // El resto de métodos no se usan en esta pantalla.
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

Widget _app(ParticipantesClase participantes) => ProviderScope(
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
    clasesRepositoryProvider.overrideWithValue(_RepoFalso(participantes)),
    tarifasProvider(true).overrideWith(
      (ref) async => [
        const Tarifa(
          id: 't1',
          academiaId: 'ac1',
          nombre: 'Mensual',
          precio: 50,
          periodicidad: 'mensual',
          activo: true,
        ),
      ],
    ),
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

  testWidgets('quien no ha pagado sale marcado en rojo', (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 900));
    await tester.pumpWidget(
      _app(
        ParticipantesClase(
          inscritos: [
            _alumno(id: 'a1', nombre: 'Moroso', sinCuota: true),
            _alumno(id: 'a2', nombre: 'Alcorriente', sinCuota: false),
          ],
          listaEspera: const [],
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Una sola marca: la del que no ha pagado.
    expect(find.text('SIN CUOTA'), findsOneWidget);
    // Y el resumen de arriba dice cuántos hay que cobrar.
    expect(find.text('1 SIN CUOTA'), findsOneWidget);

    // Roja de verdad, no un gris cualquiera: es lo que la hace saltar a la
    // vista entre veinte nombres.
    final pastilla = tester.widget<PastillaEstado>(
      find
          .byWidgetPredicate(
            (w) => w is PastillaEstado && w.texto == 'Sin cuota',
          )
          .first,
    );
    expect(pastilla.fondo, AppColors.dangerBg);
    expect(pastilla.tinta, AppColors.dangerFg);
  });

  testWidgets('si están todos al corriente no se marca a nadie', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 900));
    await tester.pumpWidget(
      _app(
        ParticipantesClase(
          inscritos: [
            _alumno(id: 'a1', nombre: 'Uno', sinCuota: false),
            _alumno(id: 'a2', nombre: 'Dos', sinCuota: false),
          ],
          listaEspera: const [],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('SIN CUOTA'), findsNothing);
    // Y se sigue viendo el cinturón, que es lo que va ahí normalmente.
    expect(find.text('Cinturón azul'), findsNWidgets(2));
  });

  testWidgets('tocar a quien no ha pagado abre el cobro en efectivo', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 900));
    await tester.pumpWidget(
      _app(
        ParticipantesClase(
          inscritos: [_alumno(id: 'a1', nombre: 'Moroso', sinCuota: true)],
          listaEspera: const [],
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Moroso Ejemplo'));
    await tester.pumpAndSettle();

    expect(find.text('Cobro en efectivo'), findsOneWidget);
    expect(find.textContaining('Para Moroso'), findsOneWidget);
  });
}
