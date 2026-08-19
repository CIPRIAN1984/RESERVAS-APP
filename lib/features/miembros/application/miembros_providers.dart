import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_state.dart';
import '../../../core/models/profile.dart';
import '../../../core/supabase/supabase_client.dart';
import '../data/miembros_repository.dart';

final miembrosRepositoryProvider = Provider<MiembrosRepository>((ref) {
  return MiembrosRepository(AppSupabase.client);
});

final alumnosMiembrosProvider = FutureProvider.autoDispose<List<Profile>>((
  ref,
) async {
  final academiaId = (await ref.watch(
    currentProfileProvider.future,
  ))?.academiaId;
  if (academiaId == null) return const [];
  return ref.watch(miembrosRepositoryProvider).listarAlumnos(academiaId);
});

final cuotaAlDiaMiembrosProvider = FutureProvider.autoDispose<Set<String>>((
  ref,
) async {
  final academiaId = (await ref.watch(
    currentProfileProvider.future,
  ))?.academiaId;
  if (academiaId == null) return const {};
  return ref.watch(miembrosRepositoryProvider).alumnosConCuotaAlDia(academiaId);
});
