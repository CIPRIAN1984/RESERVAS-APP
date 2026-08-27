import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../core/supabase/supabase_client.dart';
import '../data/estadisticas_repository.dart';
import '../data/ranking_entry.dart';

final estadisticasRepositoryProvider = Provider<EstadisticasRepository>((ref) {
  return EstadisticasRepository(AppSupabase.client);
});

/// Los tres periodos que pidió Cipri, como en MAAT: el mes en curso, el año
/// en curso o el histórico completo.
enum PeriodoRanking { mes, anio, siempre }

final periodoRankingProvider = StateProvider<PeriodoRanking>(
  (ref) => PeriodoRanking.mes,
);

final rankingPeriodoProvider = FutureProvider.autoDispose<List<RankingEntry>>((
  ref,
) {
  final periodo = ref.watch(periodoRankingProvider);
  final ahora = DateTime.now();
  final (DateTime?, DateTime?) rango = switch (periodo) {
    PeriodoRanking.mes => (
      DateTime(ahora.year, ahora.month, 1),
      DateTime(ahora.year, ahora.month + 1, 0),
    ),
    PeriodoRanking.anio => (
      DateTime(ahora.year, 1, 1),
      DateTime(ahora.year, 12, 31),
    ),
    PeriodoRanking.siempre => (null, null),
  };
  return ref
      .watch(estadisticasRepositoryProvider)
      .rankingPeriodo(desde: rango.$1, hasta: rango.$2);
});
