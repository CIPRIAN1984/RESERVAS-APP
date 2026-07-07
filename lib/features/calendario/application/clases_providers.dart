import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../core/supabase/supabase_client.dart';
import '../data/clase_resumen.dart';
import '../data/clases_repository.dart';

final clasesRepositoryProvider = Provider<ClasesRepository>((ref) {
  return ClasesRepository(AppSupabase.client);
});

DateTime firstOfMonth(DateTime day) => DateTime(day.year, day.month, 1);
DateTime firstOfNextMonth(DateTime day) => DateTime(day.year, day.month + 1, 1);

/// The first day of the month currently shown in the calendar.
final visibleMonthProvider = StateProvider<DateTime>((ref) => firstOfMonth(DateTime.now()));

/// The day selected within that month (defaults to today).
final selectedDayProvider = StateProvider<DateTime>((ref) {
  final date = DateTime.now();
  return DateTime(date.year, date.month, date.day);
});

final clasesMesProvider = FutureProvider.autoDispose<List<ClaseResumen>>((ref) async {
  final mes = ref.watch(visibleMonthProvider);
  final repo = ref.watch(clasesRepositoryProvider);
  return repo.listarClases(desde: mes, hasta: firstOfNextMonth(mes));
});
