import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:itaca/app/theme/app_theme.dart';
import 'package:itaca/core/models/profile.dart';
import 'package:itaca/features/miembros/application/miembros_providers.dart';
import 'package:itaca/features/miembros/data/miembros_repository.dart';
import 'package:itaca/features/miembros/domain/progreso_cinturon.dart';
import 'package:itaca/features/miembros/presentation/ficha_miembro_screen.dart';

/// Ficha de un alumno: cuánto lleva en su cinturón actual y cuánto le falta
/// para el siguiente — lo que Cipri pidió tras ver la pestaña «Promociones»
/// de MAAT y comprobar que, aunque ya podía filtrar por cinturón en la
/// lista, no podía entrar en la ficha de nadie a ver su progreso.

class _RepoFalso implements MiembrosRepository {
  final List<String> promociones = [];

  @override
  Future<void> promoverCinturon({
    required String alumnoId,
    required String nuevoCinturon,
  }) async {
    promociones.add('$alumnoId->$nuevoCinturon');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Profile _alumno({String? cinturon = 'blanco'}) => Profile(
  id: 'a1',
  academiaId: 'ac1',
  rol: 'alumno',
  nombre: 'Nico',
  apellidos: 'Ejemplo',
  cinturon: cinturon,
  estado: 'activo',
);

Widget _app({
  required Profile alumno,
  required ProgresoCinturon progreso,
  MiembrosRepository? repo,
  bool navegadorAnidado = false,
}) {
  final ficha = FichaMiembroScreen(alumno: alumno);
  return ProviderScope(
    overrides: [
      progresoCinturonProvider((
        alumnoId: alumno.id,
        cinturon: alumno.cinturon,
        fechaInicioCinturon: alumno.fechaInicioCinturon,
      )).overrideWith((ref) async => progreso),
      if (repo != null) miembrosRepositoryProvider.overrideWithValue(repo),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      // Con `navegadorAnidado`, la ficha cuelga de un Navigator propio
      // dentro del de MaterialApp — exactamente como en la app real, donde
      // el armazón de la barra inferior tiene el suyo. Sin esto, un fallo
      // de contexto en los diálogos (que se montan en el navegador raíz)
      // no se nota: con un solo navegador, equivocarse de contexto da
      // igual, y la prueba pasa por el motivo equivocado.
      home: navegadorAnidado
          ? Navigator(
              onGenerateRoute: (_) =>
                  MaterialPageRoute<void>(builder: (_) => ficha),
            )
          : ficha,
    ),
  );
}

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

  // El fallo que encontró Cipri probando en el móvil (02/09/2026): al
  // confirmar, se cerraba la ficha por detrás y el diálogo se quedaba
  // pegado en pantalla, sin promover a nadie. Solo se reproduce con el
  // navegador anidado del armazón, que es como está montada la app de
  // verdad — por eso la prueba de arriba, con un único navegador, no lo
  // cazaba.
  testWidgets(
    'con el armazón de verdad, confirmar promueve y cierra el diálogo',
    (tester) async {
      final repo = _RepoFalso();
      await tester.pumpWidget(
        _app(
          alumno: _alumno(cinturon: 'blanco'),
          progreso: const ProgresoCinturon(
            asistencias: 5,
            requeridas: 312,
            proximoCinturon: 'azul',
          ),
          repo: repo,
          navegadorAnidado: true,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Promover a un nuevo cinturón'));
      await tester.pumpAndSettle();
      expect(
        find.text('¿Pasar a Nico Ejemplo de Blanco a Azul?'),
        findsOneWidget,
      );

      await tester.tap(find.text('Promover'));
      await tester.pumpAndSettle();

      expect(
        repo.promociones,
        ['a1->azul'],
        reason: 'Confirmar tiene que llamar al servidor y promover de verdad.',
      );
      expect(
        find.text('¿Pasar a Nico Ejemplo de Blanco a Azul?'),
        findsNothing,
        reason: 'El diálogo no puede quedarse pegado en pantalla.',
      );
    },
  );
}
