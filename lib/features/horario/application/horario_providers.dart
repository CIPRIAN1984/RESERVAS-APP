import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_client.dart';
import '../data/horario_repository.dart';
import '../data/plantilla_clase.dart';

final horarioRepositoryProvider = Provider<HorarioRepository>((ref) {
  return HorarioRepository(AppSupabase.client);
});

final plantillasProvider = FutureProvider.autoDispose
    .family<List<PlantillaClase>, String>((ref, academiaId) {
      return ref.watch(horarioRepositoryProvider).listarPlantillas(academiaId);
    });
