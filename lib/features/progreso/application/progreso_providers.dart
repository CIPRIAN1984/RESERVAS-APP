import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_state.dart';
import '../../../core/supabase/supabase_client.dart';
import '../data/progreso_repository.dart';
import '../data/tecnica.dart';

final progresoRepositoryProvider = Provider<ProgresoRepository>((ref) {
  return ProgresoRepository(AppSupabase.client);
});

final tecnicasProvider = FutureProvider.autoDispose<List<Tecnica>>((ref) {
  return ref.watch(progresoRepositoryProvider).listarTecnicas();
});

/// tecnica_id -> estado for the signed-in user (only meaningful for Alumno).
final miProgresoProvider = FutureProvider.autoDispose<Map<String, String>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return {};
  return ref.watch(progresoRepositoryProvider).miProgreso(userId);
});
