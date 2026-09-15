import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_client.dart';
import '../data/agente_repository.dart';
import '../data/clave_agente.dart';

final agenteRepositoryProvider = Provider<AgenteRepository>((ref) {
  return AgenteRepository(AppSupabase.client);
});

final clavesAgenteProvider = FutureProvider.autoDispose<List<ClaveAgente>>((
  ref,
) {
  return ref.watch(agenteRepositoryProvider).listarClaves();
});

final consultasAgenteProvider =
    FutureProvider.autoDispose<List<ConsultaAgente>>((ref) {
      return ref.watch(agenteRepositoryProvider).ultimasConsultas();
    });
