import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_client.dart';
import '../data/cambio_escuela_repository.dart';
import '../data/solicitud_cambio_escuela.dart';

final cambioEscuelaRepositoryProvider = Provider<CambioEscuelaRepository>((
  ref,
) {
  return CambioEscuelaRepository(AppSupabase.client);
});

final misSolicitudesCambioProvider =
    FutureProvider.autoDispose<List<MiSolicitudCambio>>((ref) {
      return ref.watch(cambioEscuelaRepositoryProvider).misSolicitudes();
    });

final solicitudesCambioPendientesProvider =
    FutureProvider.autoDispose<List<SolicitudPendiente>>((ref) {
      return ref.watch(cambioEscuelaRepositoryProvider).listarPendientes();
    });
