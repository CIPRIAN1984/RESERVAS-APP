import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:itaca/app/theme/app_theme.dart';
import 'package:itaca/core/auth/auth_state.dart';
import 'package:itaca/features/estadisticas/application/estadisticas_providers.dart';
import 'package:itaca/features/estadisticas/data/estadisticas_repository.dart';
import 'package:itaca/features/estadisticas/data/ranking_entry.dart';
import 'package:itaca/features/estadisticas/presentation/estadisticas_screen.dart';

/// Cipri pidió filtrar el ranking como en MAAT: mes, año o desde siempre.
/// Lo que importa comprobar no es solo qué texto aparece, sino que cada
/// pestaña pide al repositorio el rango de fechas correcto —ahí es donde
/// vivía el riesgo real de un desliz de un día en el límite del mes o del
/// año—; el filtrado en sí ya lo comprueba la prueba pgTAP de la RPC.

class _RepoFalso implements EstadisticasRepository {
  final List<({DateTime? desde, DateTime? hasta})> llamadas = [];

  @override
  Future<List<RankingEntry>> rankingPeriodo({
    DateTime? desde,
    DateTime? hasta,
  }) async {
    llamadas.add((desde: desde, hasta: hasta));
    return const [];
  }
}

Widget _app(_RepoFalso repo) => ProviderScope(
  overrides: [
    estadisticasRepositoryProvider.overrideWithValue(repo),
    currentUserIdProvider.overrideWithValue('u1'),
  ],
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light,
    home: const Scaffold(body: EstadisticasScreen()),
  ),
);

void main() {
  setUpAll(() async {
    await initializeDateFormatting('es_ES');
  });

  testWidgets('por defecto pide el mes en curso completo', (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 900));
    final repo = _RepoFalso();
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    final ahora = DateTime.now();
    expect(repo.llamadas.last.desde, DateTime(ahora.year, ahora.month, 1));
    expect(repo.llamadas.last.hasta, DateTime(ahora.year, ahora.month + 1, 0));
  });

  testWidgets('tocar «Este año» pide el año completo, no el mes', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 900));
    final repo = _RepoFalso();
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Este año'));
    await tester.pumpAndSettle();

    final ahora = DateTime.now();
    expect(repo.llamadas.last.desde, DateTime(ahora.year, 1, 1));
    expect(repo.llamadas.last.hasta, DateTime(ahora.year, 12, 31));
    expect(find.text('${ahora.year}'), findsOneWidget);
  });

  testWidgets('tocar «Siempre» no manda ningún límite de fecha', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 900));
    final repo = _RepoFalso();
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Siempre'));
    await tester.tap(find.text('Siempre'));
    await tester.pumpAndSettle();

    expect(repo.llamadas.last.desde, isNull);
    expect(repo.llamadas.last.hasta, isNull);
    // El antetítulo de TituloPantalla se renderiza en mayúsculas.
    expect(find.text('HISTÓRICO'), findsOneWidget);
  });

  testWidgets('el estado vacío avisa del periodo elegido', (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 900));
    final repo = _RepoFalso();
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    expect(find.text('No hay clases con asistencia este mes.'), findsOneWidget);

    await tester.ensureVisible(find.text('Siempre'));
    await tester.tap(find.text('Siempre'));
    await tester.pumpAndSettle();

    expect(find.text('No hay clases con asistencia todavía.'), findsOneWidget);
  });
}
