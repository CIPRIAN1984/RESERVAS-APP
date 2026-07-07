import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_client.dart';
import '../data/suscripcion.dart';
import '../data/tarifa.dart';
import '../data/tarifas_repository.dart';

final tarifasRepositoryProvider = Provider<TarifasRepository>((ref) {
  return TarifasRepository(AppSupabase.client);
});

final tarifasProvider = FutureProvider.autoDispose.family<List<Tarifa>, bool>((
  ref,
  soloActivas,
) {
  return ref
      .watch(tarifasRepositoryProvider)
      .listarTarifas(soloActivas: soloActivas);
});

final suscripcionActivaProvider = FutureProvider.autoDispose
    .family<Suscripcion?, String>((ref, alumnoId) {
      return ref.watch(tarifasRepositoryProvider).suscripcionActiva(alumnoId);
    });
