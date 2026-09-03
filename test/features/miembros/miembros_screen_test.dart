import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:itaca/app/theme/app_theme.dart';
import 'package:itaca/core/auth/auth_state.dart';
import 'package:itaca/core/models/profile.dart';
import 'package:itaca/features/miembros/application/miembros_providers.dart';
import 'package:itaca/features/miembros/domain/progreso_cinturon.dart';
import 'package:itaca/features/miembros/presentation/miembros_screen.dart';
import 'package:itaca/features/tarifas/application/tarifas_providers.dart';

/// Cipri pidió una pantalla de Miembros como la de MAAT: buscar por nombre,
/// filtrar por cinturón (incluidos los trece de niños del sistema IBJJF) y
/// por estado (al día, sin cuota, inactivos, listos), y ver de un vistazo
/// en qué situación está cada alumno.

/// Las tarjetas del resumen son además los botones de filtro; se localizan
/// por clave porque su texto («AL DÍA», «SIN CUOTA») se repite en las
/// pastillas de cada fila.
Finder _tarjeta(String estado) => find.byKey(ValueKey('resumen-$estado'));

Profile _alumno({
  required String id,
  required String nombre,
  String? cinturon,
}) => Profile(
  id: id,
  academiaId: 'a1',
  rol: 'alumno',
  nombre: nombre,
  apellidos: 'Ejemplo',
  cinturon: cinturon,
  estado: 'activo',
);

Widget _app({
  required List<Profile> alumnos,
  required Set<String> alDia,
  Map<String, DateTime> ultimaAsistencia = const {},
  Set<String> listosParaGraduarse = const {},
}) => ProviderScope(
  overrides: [
    currentUserIdProvider.overrideWithValue('d1'),
    currentProfileProvider.overrideWith(
      (ref) async => Profile(
        id: 'd1',
        academiaId: 'a1',
        rol: 'dueño',
        nombre: 'Dueño',
        estado: 'activo',
      ),
    ),
    alumnosMiembrosProvider.overrideWith((ref) async => alumnos),
    cuotaAlDiaMiembrosProvider.overrideWith((ref) async => alDia),
    ultimaAsistenciaMiembrosProvider.overrideWith(
      (ref) async => ultimaAsistencia,
    ),
    graduacionMiembrosProvider.overrideWith((ref) async => listosParaGraduarse),
    // Para cuando se toca a quien no tiene cuota: la hoja de cobro en
    // efectivo necesita las tarifas para renderizarse sin quedarse
    // cargando para siempre.
    tarifasProvider(true).overrideWith((ref) async => const []),
    for (final alumno in alumnos)
      progresoCinturonProvider((
        alumnoId: alumno.id,
        cinturon: alumno.cinturon,
        fechaInicioCinturon: alumno.fechaInicioCinturon,
      )).overrideWith(
        (ref) async => const ProgresoCinturon(
          asistencias: 0,
          requeridas: 78,
          proximoCinturon: 'gris_blanco',
        ),
      ),
  ],
  child: MaterialApp(
    theme: AppTheme.light,
    home: const Scaffold(body: MiembrosScreen()),
  ),
);

void main() {
  testWidgets('enseña a todos los alumnos con su estado de cuota', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 900));
    await tester.pumpWidget(
      _app(
        alumnos: [
          _alumno(id: 'a1', nombre: 'Ana', cinturon: 'azul'),
          _alumno(id: 'a2', nombre: 'Beto', cinturon: 'blanco'),
        ],
        alDia: {'a1'},
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ana Ejemplo'), findsOneWidget);
    expect(find.text('Beto Ejemplo'), findsOneWidget);
    // Contadores del resumen.
    expect(find.text('1'), findsNWidgets(2));
    expect(find.text('2 ALUMNOS'), findsOneWidget);
  });

  testWidgets('buscar por nombre filtra la lista', (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 900));
    await tester.pumpWidget(
      _app(
        alumnos: [
          _alumno(id: 'a1', nombre: 'Ana', cinturon: 'azul'),
          _alumno(id: 'a2', nombre: 'Beto', cinturon: 'blanco'),
        ],
        alDia: const {},
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'ana');
    await tester.pumpAndSettle();

    expect(find.text('Ana Ejemplo'), findsOneWidget);
    expect(find.text('Beto Ejemplo'), findsNothing);
    expect(find.text('1 DE 2 ALUMNOS'), findsOneWidget);
  });

  testWidgets('el filtro de cinturón deja solo a quien lo tiene', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 900));
    await tester.pumpWidget(
      _app(
        alumnos: [
          _alumno(id: 'a1', nombre: 'Ana', cinturon: 'azul'),
          _alumno(id: 'a2', nombre: 'Beto', cinturon: 'blanco'),
        ],
        alDia: const {},
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cinturón'));
    await tester.pumpAndSettle();

    expect(
      find.text('Adultos'),
      findsOneWidget,
      reason: 'La hoja distingue cinturones de adulto y de niño.',
    );

    await tester.tap(find.text('AZUL'));
    await tester.pumpAndSettle();

    expect(find.text('Ana Ejemplo'), findsOneWidget);
    expect(find.text('Beto Ejemplo'), findsNothing);
    // El botón pasa a mostrar el cinturón elegido.
    expect(find.text('Azul'), findsOneWidget);
  });

  testWidgets(
    'sin cinturón asignado cuenta como blanco al filtrar, igual que en la ficha',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(412, 900));
      await tester.pumpWidget(
        _app(
          alumnos: [
            _alumno(id: 'a1', nombre: 'Ana', cinturon: 'azul'),
            // Sin cinturon: dato en blanco, como un alumno recién dado de
            // alta al que todavía no se le ha puesto ninguno.
            _alumno(id: 'a2', nombre: 'Beto'),
          ],
          alDia: const {},
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('BLANCO ·'),
        findsOneWidget,
        reason: 'Sin dato, la fila ya lo muestra como Blanco.',
      );

      await tester.tap(find.text('Cinturón'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('BLANCO'));
      await tester.pumpAndSettle();

      expect(
        find.text('Beto Ejemplo'),
        findsOneWidget,
        reason: 'Sin cinturón asignado, filtrar por "Blanco" debe incluirlo.',
      );
      expect(find.text('Ana Ejemplo'), findsNothing);
    },
  );

  testWidgets('un cinturón de niño también se puede filtrar', (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 900));
    await tester.pumpWidget(
      _app(
        alumnos: [
          _alumno(id: 'a1', nombre: 'Ana', cinturon: 'azul'),
          _alumno(id: 'a2', nombre: 'Nico', cinturon: 'amarillo_negro'),
        ],
        alDia: const {},
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cinturón'));
    await tester.pumpAndSettle();
    await tester.dragUntilVisible(
      find.text('AMARILLO-NEGRO'),
      find.byType(Scrollable).last,
      const Offset(0, 50),
    );
    await tester.tap(find.text('AMARILLO-NEGRO'));
    await tester.pumpAndSettle();

    expect(find.text('Nico Ejemplo'), findsOneWidget);
    expect(find.text('Ana Ejemplo'), findsNothing);
    expect(find.textContaining('AMARILLO-NEGRO ·'), findsOneWidget);
  });

  testWidgets('elegir «Todos» en la hoja quita el filtro', (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 900));
    await tester.pumpWidget(
      _app(
        alumnos: [
          _alumno(id: 'a1', nombre: 'Ana', cinturon: 'azul'),
          _alumno(id: 'a2', nombre: 'Beto', cinturon: 'blanco'),
        ],
        alDia: const {},
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cinturón'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('AZUL'));
    await tester.pumpAndSettle();
    expect(find.text('Beto Ejemplo'), findsNothing);

    await tester.tap(find.text('Azul'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('TODOS'));
    await tester.pumpAndSettle();

    expect(find.text('Ana Ejemplo'), findsOneWidget);
    expect(find.text('Beto Ejemplo'), findsOneWidget);
  });

  testWidgets('sin alumnos en la academia, lo dice claramente', (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 900));
    await tester.pumpWidget(_app(alumnos: const [], alDia: const {}));
    await tester.pumpAndSettle();

    expect(find.text('Todavía no hay alumnos en la academia.'), findsOneWidget);
  });

  testWidgets('tocar a un alumno abre su ficha', (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 900));
    await tester.pumpWidget(
      _app(
        alumnos: [_alumno(id: 'a1', nombre: 'Ana', cinturon: 'azul')],
        alDia: {'a1'},
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ana Ejemplo'));
    await tester.pumpAndSettle();

    expect(
      find.text('Promover a un nuevo cinturón'),
      findsOneWidget,
      reason: 'La ficha del alumno se abre con su progreso de cinturón.',
    );
  });

  testWidgets(
    'quien no tiene ninguna asistencia se marca como que nunca ha venido',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(412, 900));
      await tester.pumpWidget(
        _app(
          alumnos: [_alumno(id: 'a1', nombre: 'Ana', cinturon: 'azul')],
          alDia: {'a1'},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('NUNCA HA VENIDO'), findsOneWidget);
      expect(find.text('INACTIVO'), findsOneWidget);
    },
  );

  testWidgets('quien entrenó hace poco no se marca como inactivo', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 900));
    await tester.pumpWidget(
      _app(
        alumnos: [_alumno(id: 'a1', nombre: 'Ana', cinturon: 'azul')],
        alDia: {'a1'},
        ultimaAsistencia: {
          'a1': DateTime.now().subtract(const Duration(days: 2)),
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('HACE 2 DÍAS'), findsOneWidget);
    expect(
      find.text('INACTIVO'),
      findsNothing,
      reason: 'Dos días sin entrenar no es una ausencia que haya que avisar.',
    );
  });

  testWidgets(
    'quien lleva muchos días sin entrenar se marca como inactivo, en el resumen y en su fila',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(412, 900));
      await tester.pumpWidget(
        _app(
          alumnos: [
            _alumno(id: 'a1', nombre: 'Ana', cinturon: 'azul'),
            _alumno(id: 'a2', nombre: 'Beto', cinturon: 'blanco'),
          ],
          alDia: {'a1', 'a2'},
          ultimaAsistencia: {
            'a1': DateTime.now().subtract(const Duration(days: 2)),
            'a2': DateTime.now().subtract(const Duration(days: 30)),
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('HACE 30 DÍAS'), findsOneWidget);
      expect(find.text('INACTIVO'), findsOneWidget);
      // Contadores: Al día 2, Sin cuota 0, Inactivos 1 (solo Beto), Listos 0.
      expect(find.text('2'), findsOneWidget);
      expect(find.text('0'), findsNWidgets(2));
      expect(find.text('1'), findsOneWidget);
    },
  );

  testWidgets(
    'quien ya cumple los entrenos se marca como listo para graduarse, en el resumen y en su fila',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(412, 900));
      await tester.pumpWidget(
        _app(
          alumnos: [
            _alumno(id: 'a1', nombre: 'Ana', cinturon: 'azul'),
            _alumno(id: 'a2', nombre: 'Beto', cinturon: 'blanco'),
          ],
          alDia: {'a1', 'a2'},
          listosParaGraduarse: {'a1'},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('LISTO PARA GRADUARSE'), findsOneWidget);
      // Contadores: Al día 2, Sin cuota 0, Inactivos 2 (nadie tiene fecha de
      // última asistencia en este escenario), Listos 1 (solo Ana).
      expect(find.text('1'), findsOneWidget);
    },
  );

  // Lo que Cipri echaba en falta: «aun no se puede filtrar por (al día,
  // inactivos...)». Las tarjetas del resumen contaban, pero no filtraban.
  testWidgets('tocar una tarjeta del resumen filtra la lista por ese estado', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 900));
    await tester.pumpWidget(
      _app(
        alumnos: [
          _alumno(id: 'a1', nombre: 'Ana', cinturon: 'azul'),
          _alumno(id: 'a2', nombre: 'Beto', cinturon: 'blanco'),
        ],
        alDia: {'a1'},
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(_tarjeta('sinCuota'));
    await tester.pumpAndSettle();

    expect(find.text('Beto Ejemplo'), findsOneWidget);
    expect(find.text('Ana Ejemplo'), findsNothing);
    expect(find.text('1 DE 2 ALUMNOS'), findsOneWidget);
  });

  testWidgets('volver a tocar la misma tarjeta quita el filtro', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 900));
    await tester.pumpWidget(
      _app(
        alumnos: [
          _alumno(id: 'a1', nombre: 'Ana', cinturon: 'azul'),
          _alumno(id: 'a2', nombre: 'Beto', cinturon: 'blanco'),
        ],
        alDia: {'a1'},
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(_tarjeta('alDia'));
    await tester.pumpAndSettle();
    expect(find.text('Beto Ejemplo'), findsNothing);

    await tester.tap(_tarjeta('alDia'));
    await tester.pumpAndSettle();
    expect(find.text('Beto Ejemplo'), findsOneWidget);
    expect(find.text('Ana Ejemplo'), findsOneWidget);
  });

  testWidgets('los filtros de estado y de cinturón se combinan', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 900));
    await tester.pumpWidget(
      _app(
        alumnos: [
          _alumno(id: 'a1', nombre: 'Ana', cinturon: 'azul'),
          _alumno(id: 'a2', nombre: 'Beto', cinturon: 'azul'),
          _alumno(id: 'a3', nombre: 'Carla', cinturon: 'blanco'),
        ],
        alDia: {'a1', 'a3'},
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(_tarjeta('alDia'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cinturón'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('AZUL'));
    await tester.pumpAndSettle();

    expect(
      find.text('Ana Ejemplo'),
      findsOneWidget,
      reason: 'Ana es la única azul con la cuota al día.',
    );
    expect(find.text('Beto Ejemplo'), findsNothing);
    expect(find.text('Carla Ejemplo'), findsNothing);
  });

  testWidgets('«Ver todos» deja la lista como estaba', (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 900));
    await tester.pumpWidget(
      _app(
        alumnos: [
          _alumno(id: 'a1', nombre: 'Ana', cinturon: 'azul'),
          _alumno(id: 'a2', nombre: 'Beto', cinturon: 'blanco'),
        ],
        alDia: {'a1'},
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Ver todos'),
      findsNothing,
      reason: 'Sin filtros puestos no hay nada que quitar.',
    );

    await tester.tap(_tarjeta('alDia'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ver todos'));
    await tester.pumpAndSettle();

    expect(find.text('Ana Ejemplo'), findsOneWidget);
    expect(find.text('Beto Ejemplo'), findsOneWidget);
    expect(find.text('2 ALUMNOS'), findsOneWidget);
  });

  testWidgets('la lista agrupa a los alumnos por su inicial', (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 900));
    await tester.pumpWidget(
      _app(
        alumnos: [
          _alumno(id: 'a1', nombre: 'Ana', cinturon: 'azul'),
          _alumno(id: 'a2', nombre: 'Alba', cinturon: 'azul'),
          _alumno(id: 'a3', nombre: 'Beto', cinturon: 'blanco'),
        ],
        alDia: const {},
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('A'),
      findsOneWidget,
      reason: 'Ana y Alba comparten una sola cabecera.',
    );
    expect(find.text('B'), findsOneWidget);
  });

  testWidgets(
    'a quien no tiene cuota se le cobra desde el botón de su fila, no tocando la fila',
    (tester) async {
      await initializeDateFormatting('es_ES');
      await tester.binding.setSurfaceSize(const Size(412, 900));
      await tester.pumpWidget(
        _app(
          alumnos: [_alumno(id: 'a1', nombre: 'Ana', cinturon: 'azul')],
          alDia: const {},
        ),
      );
      await tester.pumpAndSettle();

      // Tocar la fila abre la ficha, igual que con cualquier otro alumno:
      // el mismo gesto no puede hacer dos cosas distintas según quién sea.
      await tester.tap(find.text('Ana Ejemplo'));
      await tester.pumpAndSettle();
      expect(find.text('Promover a un nuevo cinturón'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Registrar cobro en efectivo'));
      await tester.pumpAndSettle();

      expect(
        find.text('Registrar cobro'),
        findsOneWidget,
        reason: 'El botón de la fila abre la hoja de cobro en efectivo.',
      );
    },
  );

  testWidgets('a quien ya está al día no se le ofrece cobrar', (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 900));
    await tester.pumpWidget(
      _app(
        alumnos: [_alumno(id: 'a1', nombre: 'Ana', cinturon: 'azul')],
        alDia: {'a1'},
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('Registrar cobro en efectivo'), findsNothing);
  });
}
