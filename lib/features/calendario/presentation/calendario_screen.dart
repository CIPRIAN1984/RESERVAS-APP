import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../app/theme/color_tokens.dart';
import '../../../core/auth/auth_state.dart';
import '../application/clases_providers.dart';
import '../data/clase_resumen.dart';
import 'clase_detalle_screen.dart';
import 'clase_card.dart';
import 'crear_clase_screen.dart';

class CalendarioScreen extends ConsumerStatefulWidget {
  const CalendarioScreen({super.key});

  @override
  ConsumerState<CalendarioScreen> createState() => _CalendarioScreenState();
}

class _CalendarioScreenState extends ConsumerState<CalendarioScreen> {
  String? _accionEnCursoClaseId;

  Future<void> _unirse(ClaseResumen clase, String alumnoId) async {
    setState(() => _accionEnCursoClaseId = clase.id);
    try {
      await ref
          .read(clasesRepositoryProvider)
          .unirse(claseId: clase.id, alumnoId: alumnoId);
      ref.invalidate(clasesMesProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_mensajeError(e))));
      }
    } finally {
      if (mounted) setState(() => _accionEnCursoClaseId = null);
    }
  }

  Future<void> _borrarse(ClaseResumen clase, String alumnoId) async {
    setState(() => _accionEnCursoClaseId = clase.id);
    try {
      await ref
          .read(clasesRepositoryProvider)
          .borrarse(claseId: clase.id, alumnoId: alumnoId);
      ref.invalidate(clasesMesProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se ha podido completar la acción.')),
        );
      }
    } finally {
      if (mounted) setState(() => _accionEnCursoClaseId = null);
    }
  }

  String _mensajeError(Object e) {
    final texto = e.toString();
    if (texto.contains('Aforo completo')) {
      return 'Aforo completo para esta clase.';
    }
    return 'No se ha podido completar la acción.';
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentProfileProvider).value;
    final userId = ref.watch(currentUserIdProvider);
    final academiaId = profile?.academiaId;
    final puedeGestionar =
        profile != null &&
        (profile.isProfesor || profile.isDueno || profile.isAdministrador);

    final selectedDay = ref.watch(selectedDayProvider);
    final visibleMonth = ref.watch(visibleMonthProvider);
    final clasesAsync = ref.watch(clasesMesProvider);

    final clasesPorDia = <DateTime, List<ClaseResumen>>{};
    for (final c in clasesAsync.value ?? const <ClaseResumen>[]) {
      final dia = c.fechaHoraInicio.toLocal();
      final key = DateTime(dia.year, dia.month, dia.day);
      clasesPorDia.putIfAbsent(key, () => []).add(c);
    }

    return Scaffold(
      floatingActionButton: (puedeGestionar && academiaId != null)
          ? FloatingActionButton.extended(
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => CrearClaseScreen(
                      academiaId: academiaId,
                      profesorId: userId!,
                    ),
                  ),
                );
                ref.invalidate(clasesMesProvider);
              },
              icon: const Icon(Icons.add),
              label: const Text('Crear clase'),
            )
          : null,
      body: Column(
        children: [
          TableCalendar<ClaseResumen>(
            firstDay: DateTime.now().subtract(const Duration(days: 365)),
            lastDay: DateTime.now().add(const Duration(days: 365)),
            focusedDay:
                visibleMonth.month == selectedDay.month &&
                    visibleMonth.year == selectedDay.year
                ? selectedDay
                : visibleMonth,
            calendarFormat: CalendarFormat.month,
            availableCalendarFormats: const {CalendarFormat.month: 'Mes'},
            startingDayOfWeek: StartingDayOfWeek.monday,
            headerStyle: const HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
            ),
            calendarStyle: const CalendarStyle(
              markerDecoration: BoxDecoration(
                color: AppColors.accentPrimary,
                shape: BoxShape.circle,
              ),
              todayDecoration: BoxDecoration(
                color: AppColors.surfaceElevatedHigh,
                shape: BoxShape.circle,
              ),
              selectedDecoration: BoxDecoration(
                color: AppColors.accentPrimary,
                shape: BoxShape.circle,
              ),
            ),
            selectedDayPredicate: (day) => isSameDay(day, selectedDay),
            eventLoader: (day) =>
                clasesPorDia[DateTime(day.year, day.month, day.day)] ??
                const [],
            onDaySelected: (selected, focused) {
              ref.read(selectedDayProvider.notifier).state = DateTime(
                selected.year,
                selected.month,
                selected.day,
              );
            },
            onPageChanged: (focused) {
              ref.read(visibleMonthProvider.notifier).state = firstOfMonth(
                focused,
              );
            },
          ),
          const Divider(height: 1, color: AppColors.divider),
          Expanded(
            child: clasesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Center(
                child: Text(
                  'No se han podido cargar las clases.',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
              data: (clases) {
                final delDia = clases
                    .where(
                      (c) =>
                          isSameDay(c.fechaHoraInicio.toLocal(), selectedDay),
                    )
                    .toList();
                if (delDia.isEmpty) {
                  return Center(
                    child: Text(
                      'No hay clases este día.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: delDia.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final clase = delDia[index];
                    final cargando = _accionEnCursoClaseId == clase.id;
                    if (puedeGestionar) {
                      return ClaseCard(
                        clase: clase,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ClaseDetalleScreen(clase: clase),
                          ),
                        ),
                      );
                    }
                    return ClaseCard(
                      clase: clase,
                      loadingAccion: cargando,
                      onUnirse: userId == null
                          ? null
                          : () => _unirse(clase, userId),
                      onBorrarse: userId == null
                          ? null
                          : () => _borrarse(clase, userId),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
