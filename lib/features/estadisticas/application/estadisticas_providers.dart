import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_client.dart';
import '../data/estadisticas_repository.dart';
import '../data/ranking_entry.dart';

final estadisticasRepositoryProvider = Provider<EstadisticasRepository>((ref) {
  return EstadisticasRepository(AppSupabase.client);
});

final rankingMensualProvider = FutureProvider.autoDispose<List<RankingEntry>>((
  ref,
) {
  final ahora = DateTime.now();
  return ref
      .watch(estadisticasRepositoryProvider)
      .rankingMensual(DateTime(ahora.year, ahora.month));
});
