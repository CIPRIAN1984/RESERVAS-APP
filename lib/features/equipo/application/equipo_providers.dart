import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_state.dart';
import '../../../core/models/profile.dart';
import '../../../core/supabase/supabase_client.dart';
import '../data/equipo_repository.dart';

final equipoRepositoryProvider = Provider<EquipoRepository>((ref) {
  return EquipoRepository(AppSupabase.client);
});

final miembrosEquipoProvider = FutureProvider.autoDispose<List<Profile>>((
  ref,
) async {
  final profile = await ref.watch(currentProfileProvider.future);
  final academiaId = profile?.academiaId;
  if (academiaId == null || !(profile?.isDueno ?? false)) return const [];
  return ref.watch(equipoRepositoryProvider).listMiembros(academiaId);
});

/// Quién tiene cuota activa ahora mismo, indexado por alumno.
///
/// Se pide una sola vez para toda la academia: hacer una consulta por cada
/// fila de la lista sería lento y machacaría la base de datos con 166 alumnos.
final cuotasActivasProvider =
    FutureProvider.autoDispose<
      Map<String, ({String id, String tarifa, bool efectivo, String estado})>
    >((ref) async {
      final profile = await ref.watch(currentProfileProvider.future);
      final academiaId = profile?.academiaId;
      if (academiaId == null || !(profile?.isDueno ?? false)) return const {};
      return ref.watch(equipoRepositoryProvider).cuotasActivas(academiaId);
    });
