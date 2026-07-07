import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_client.dart';
import '../data/novedad.dart';
import '../data/novedades_repository.dart';

final novedadesRepositoryProvider = Provider<NovedadesRepository>((ref) {
  return NovedadesRepository(AppSupabase.client);
});

final novedadesProvider = FutureProvider.autoDispose<List<Novedad>>((ref) {
  return ref.watch(novedadesRepositoryProvider).listar();
});
