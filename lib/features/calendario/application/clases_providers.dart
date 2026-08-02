import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../core/supabase/supabase_client.dart';
import '../data/clase_resumen.dart';
import '../data/clases_repository.dart';

final clasesRepositoryProvider = Provider<ClasesRepository>((ref) {
  return ClasesRepository(AppSupabase.client);
});

/// El lunes de la semana a la que pertenece [day].
///
/// `weekday` va de 1 (lunes) a 7 (domingo), así que restar `weekday - 1` días
/// siempre cae en lunes, sea cual sea el día de partida.
DateTime mondayOf(DateTime day) {
  final fecha = DateTime(day.year, day.month, day.day);
  return fecha.subtract(Duration(days: fecha.weekday - 1));
}

DateTime nextMonday(DateTime monday) => monday.add(const Duration(days: 7));

/// El lunes de la semana que se ve ahora mismo en el calendario.
final visibleWeekProvider = StateProvider<DateTime>(
  (ref) => mondayOf(DateTime.now()),
);

/// El día seleccionado dentro de esa semana (por defecto, hoy).
final selectedDayProvider = StateProvider<DateTime>((ref) {
  final date = DateTime.now();
  return DateTime(date.year, date.month, date.day);
});

/// Las clases de la semana visible. Coincide con lo que espera la RPC del
/// servidor, `listar_clases_semana`: antes se pedía el mes entero para
/// enseñar solo una semana de pastillas, que era pedir de más.
final clasesSemanaProvider = FutureProvider.autoDispose<List<ClaseResumen>>((
  ref,
) async {
  final lunes = ref.watch(visibleWeekProvider);
  final repo = ref.watch(clasesRepositoryProvider);
  return repo.listarClases(desde: lunes, hasta: nextMonday(lunes));
});
