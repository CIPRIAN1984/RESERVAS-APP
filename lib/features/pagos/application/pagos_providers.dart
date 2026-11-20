import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_client.dart';
import '../data/pago_tarjeta.dart';
import '../data/pagos_repository.dart';

final pagosRepositoryProvider = Provider<PagosRepository>((ref) {
  return PagosRepository(AppSupabase.client);
});

/// Pagos con tarjeta que el Dueño tiene que revisar.
final pagosConProblemaProvider = FutureProvider.autoDispose<List<PagoTarjeta>>(
  (ref) => ref.watch(pagosRepositoryProvider).pagosConProblema(),
);
