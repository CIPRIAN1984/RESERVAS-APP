import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:itaca/app/theme/app_theme.dart';
import 'package:itaca/core/models/profile.dart';
import 'package:itaca/features/miembros/application/miembros_providers.dart';
import 'package:itaca/features/miembros/domain/progreso_cinturon.dart';
import 'package:itaca/features/miembros/presentation/ficha_miembro_screen.dart';

/// Ficha de un alumno: cuánto lleva en su cinturón actual y cuánto le falta
/// para el siguiente — lo que Cipri pidió tras ver la pestaña «Promociones»
/// de MAAT y comprobar que, aunque ya podía filtrar por cinturón en la
/// lista, no podía entrar en la ficha de nadie a ver su progreso.

Profile _alumno({String? cinturon = 'blanco'}) => Profile(
  id: 'a1',
  academiaId: 'ac1',
  rol: 'alumno',
  nombre: 'Nico',
  apellidos: 'Ejemplo',
  cinturon: cinturon,
  estado: 'activo',
);

Widget _app({required Profile alumno, required ProgresoCinturon progreso}) =>
    ProviderScope(
      overrides: [
        progresoCinturonProvider((
          alumnoId: alumno.id,
          cinturon: alumno.cinturon,
          fechaInicioCinturon: alumno.fechaInicioCinturon,
        )).overrideWith((ref) async => progreso),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: FichaMiembroScreen(alumno: alumno),
      ),
    );

void main() {
  testWidgets('enseña el cinturón actual, el siguiente y el progreso', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        alumno: _alumno(cinturon: 'gris'),
        progreso: const ProgresoCinturon(
          asistencias: 39,
          requeridas: 78,
          proximoCinturon: 'gris_negro',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nico Ejemplo'), findsOneWidget);
    expect(find.text('Gris'), findsOneWidget);
    expect(find.text('Gris-Negro'), findsOneWidget);
    expect(find.text('50%'), findsOneWidget);
    expect(
      find.text(
        'Ha completado 39 de las 78 clases totales requeridas para el '
        'siguiente cinturón.',
      ),
      findsOneWidget,
    );
    expect(find.text('Promover a un nuevo cinturón'), findsOneWidget);
  });

  testWidgets('en el cinturón más alto no hay anillo ni botón de promover', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        alumno: _alumno(cinturon: 'negro'),
        progreso: const ProgresoCinturon(
          asistencias: 900,
          requeridas: 312,
          proximoCinturon: null,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Ya tiene el cinturón más alto que gestionamos aquí.'),
      findsOneWidget,
    );
    expect(find.text('Promover a un nuevo cinturón'), findsNothing);
  });

  testWidgets('promover pide confirmación con los nombres de los cinturones', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        alumno: _alumno(cinturon: 'blanco'),
        progreso: const ProgresoCinturon(
          asistencias: 312,
          requeridas: 312,
          proximoCinturon: 'azul',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Promover a un nuevo cinturón'));
    await tester.pumpAndSettle();

    expect(
      find.text('¿Pasar a Nico Ejemplo de Blanco a Azul?'),
      findsOneWidget,
    );

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(
      find.text('¿Pasar a Nico Ejemplo de Blanco a Azul?'),
      findsNothing,
      reason: 'Cancelar cierra el diálogo sin llamar al servidor.',
    );
  });
}
