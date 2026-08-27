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
/// ver de un vistazo quién tiene la cuota al día. Lo que exige datos que la
/// base de datos todavía no tiene (prueba/pausada, listo para graduarse,
/// inactividad) queda para una tanda futura, decidida con él.

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

Widget _app({required List<Profile> alumnos, required Set<String> alDia}) =>
    ProviderScope(
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
    expect(find.text('Cinturón Amarillo-Negro'), findsOneWidget);
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

  testWidgets('tocar a quien tiene la cuota al día abre su ficha', (
    tester,
  ) async {
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
    'tocar a quien no tiene cuota sigue abriendo el cobro en efectivo, no la ficha',
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

      await tester.tap(find.text('Ana Ejemplo'));
      await tester.pumpAndSettle();

      expect(
        find.text('Promover a un nuevo cinturón'),
        findsNothing,
        reason:
            'Sin cuota al día, el hueco se sigue usando para cobrar, no para la ficha.',
      );
      expect(
        find.text('Registrar cobro'),
        findsOneWidget,
        reason: 'Se abre la hoja de cobro en efectivo, como antes.',
      );
    },
  );
}
