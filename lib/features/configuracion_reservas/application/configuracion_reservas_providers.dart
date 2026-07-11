import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_client.dart';
import '../data/configuracion_reservas.dart';
import '../data/configuracion_reservas_repository.dart';

final configuracionReservasRepositoryProvider =
    Provider<ConfiguracionReservasRepository>((ref) {
      return ConfiguracionReservasRepository(AppSupabase.client);
    });

final configuracionReservasProvider = FutureProvider.autoDispose
    .family<ConfiguracionReservas, String>((ref, academiaId) {
      return ref
          .watch(configuracionReservasRepositoryProvider)
          .obtener(academiaId);
    });
