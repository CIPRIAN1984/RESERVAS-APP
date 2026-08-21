import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_state.dart';
import '../../../core/models/profile.dart';
import '../../../core/supabase/supabase_client.dart';
import '../data/miembros_repository.dart';
import '../domain/progreso_cinturon.dart';

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

/// Progreso de un alumno hacia su siguiente cinturón — para la ficha de
/// Miembros. La clave lleva su cinturón y fecha de inicio (en vez de solo
/// el id) para que un cambio de cualquiera de los dos recalcule sin
/// depender de invalidar el provider a mano.
///
/// `fechaInicioCinturon` nulo (no debería pasar tras la migración, pero es
/// defensivo) cuenta desde ahora mismo, calculado aquí dentro y no en la
/// clave — para que la clave sea estable y comparable.
final progresoCinturonProvider = FutureProvider.autoDispose
    .family<
      ProgresoCinturon,
      ({String alumnoId, String? cinturon, DateTime? fechaInicioCinturon})
    >((ref, params) async {
      final repo = ref.watch(miembrosRepositoryProvider);
      final desde = params.fechaInicioCinturon ?? DateTime.now();
      final esMenor = await repo.esMenor(params.alumnoId);
      final asistencias = await repo.contarAsistenciasDesde(
        params.alumnoId,
        desde,
      );
      return ProgresoCinturon(
        asistencias: asistencias,
        requeridas: asistenciasRequeridas(esMenor),
        proximoCinturon: proximoCinturon(params.cinturon, esMenor),
      );
    });
