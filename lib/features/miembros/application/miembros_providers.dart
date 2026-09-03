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

/// Cuándo entrenó cada alumno por última vez, para marcar en Miembros a
/// quien lleva tiempo sin venir. Una sola consulta para toda la academia,
/// igual que [cuotaAlDiaMiembrosProvider].
final ultimaAsistenciaMiembrosProvider =
    FutureProvider.autoDispose<Map<String, DateTime>>((ref) async {
      final academiaId = (await ref.watch(
        currentProfileProvider.future,
      ))?.academiaId;
      if (academiaId == null) return const {};
      return ref.watch(miembrosRepositoryProvider).ultimaAsistenciaPorAlumno();
    });

/// Quién ya cumple los entrenos que hacen falta para el siguiente
/// cinturón, para marcarlo en Miembros sin abrir la ficha de cada alumno.
/// Aplica las mismas reglas que [progresoCinturonProvider] (niños/adultos,
/// próximo cinturón según la escala que toque), pero de golpe para toda la
/// academia en vez de una por una.
final graduacionMiembrosProvider = FutureProvider.autoDispose<Set<String>>((
  ref,
) async {
  final academiaId = (await ref.watch(
    currentProfileProvider.future,
  ))?.academiaId;
  if (academiaId == null) return const {};

  final repo = ref.watch(miembrosRepositoryProvider);
  final alumnos = await ref.watch(alumnosMiembrosProvider.future);
  final progreso = await repo.progresoGraduacionAlumnos();

  return {
    for (final alumno in alumnos)
      if (progreso[alumno.id] case final datos?)
        if (proximoCinturon(alumno.cinturon, datos.esMenor) != null &&
            datos.asistencias >= asistenciasRequeridas(datos.esMenor))
          alumno.id,
  };
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
