@Tags(['golden'])

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:itaca/app/theme/app_theme.dart';
import 'package:itaca/core/auth/auth_state.dart';
import 'package:itaca/features/estadisticas/application/estadisticas_providers.dart';
import 'package:itaca/features/estadisticas/data/ranking_entry.dart';
import 'package:itaca/features/estadisticas/presentation/estadisticas_screen.dart';

import 'ayuda_golden.dart';

RankingEntry _alumno(String nombre, String cinturon, int clases) =>
    RankingEntry(
      alumnoId: 'id-$nombre',
      nombre: nombre,
      apellidos: 'Ejemplo',
      cinturon: cinturon,
      asistenciasCount: clases,
    );

/// Ranking de ejemplo, ya ordenado de más a menos asistencias.
final _ranking = [
  _alumno('Alumno D', 'negro', 22),
  _alumno('Alumno F', 'marron', 19),
  _alumno('Alumno C', 'morado', 17),
  _alumno('Alumno A', 'azul', 12),
  _alumno('Alumno G', 'azul', 9),
  _alumno('Alumno B', 'blanco', 4),
];

void main() {
  setUpAll(cargarTipografias);

  testWidgets('Ranking con podio y clasificación', (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 900));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          rankingMensualProvider.overrideWith((ref) async => _ranking),
          // El cuarto clasificado es "yo": su fila debe destacarse.
          currentUserIdProvider.overrideWithValue('id-Alumno A'),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          home: const Scaffold(body: EstadisticasScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Top 3 del mes'), findsOneWidget);
    expect(find.text('Clasificación'), findsOneWidget);

    await comparaCon(
      find.byType(MaterialApp),
      'goldens/estadisticas_ranking.png',
    );
  });

  testWidgets('Sin alumnos muestra un estado vacío cuidado', (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 500));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          rankingMensualProvider.overrideWith((ref) async => <RankingEntry>[]),
          currentUserIdProvider.overrideWithValue(null),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          home: const Scaffold(body: EstadisticasScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Todavía no hay clases con asistencia este mes.'),
      findsOneWidget,
    );
    // El estado vacío sustituía la pantalla entera y se llevaba por delante
    // la cabecera: no sabías ni en qué pantalla estabas.
    expect(find.text('Estadísticas'), findsOneWidget);
  });
}
