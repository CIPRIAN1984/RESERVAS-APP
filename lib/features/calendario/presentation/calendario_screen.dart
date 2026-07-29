import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../app/app_mode.dart';
import '../../../app/theme/color_tokens.dart';
import '../../../core/auth/auth_state.dart';
import '../../../shared/widgets/pantalla.dart';
import '../application/clases_providers.dart';
import '../data/clase_resumen.dart';
import 'clase_card.dart';
import 'clase_detalle_screen.dart';
import 'crear_clase_screen.dart';

class CalendarioScreen extends ConsumerStatefulWidget {
  const CalendarioScreen({super.key});

  @override
  ConsumerState<CalendarioScreen> createState() => _CalendarioScreenState();
}

class _CalendarioScreenState extends ConsumerState<CalendarioScreen> {
  String? _accionEnCursoClaseId;

  Future<void> _unirse(ClaseResumen clase) async {
    setState(() => _accionEnCursoClaseId = clase.id);
    try {
      final estado = await ref
          .read(clasesRepositoryProvider)
          .unirse(claseId: clase.id);
      ref.invalidate(clasesMesProvider);
      if (mounted && estado == 'espera') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Clase completa: estás en la lista de espera.'),
          ),
        );
      }
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

  Future<void> _borrarse(ClaseResumen clase) async {
    setState(() => _accionEnCursoClaseId = clase.id);
    try {
      final tardia = await ref
          .read(clasesRepositoryProvider)
          .borrarse(claseId: clase.id);
      ref.invalidate(clasesMesProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              tardia
                  ? 'Reserva cancelada. La cancelación queda registrada como tardía.'
                  : 'Reserva cancelada correctamente.',
            ),
          ),
        );
      }
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
    if (texto.contains('cuota activa')) {
      return 'Necesitas una cuota activa para reservar.';
    }
    if (texto.contains('Ya estás inscrito') ||
        texto.contains('Ya tienes una reserva')) {
      return 'Ya tienes una reserva o plaza de espera para esta clase.';
    }
    if (texto.contains('clases futuras')) {
      return 'Esta clase ya ha comenzado.';
    }
    return 'No se ha podido completar la acción.';
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentProfileProvider).value;
    final userId = ref.watch(currentUserIdProvider);
    final academiaId = profile?.academiaId;
    // Por MODO, no por rol: un dueño en modo Entrenamiento viene a apuntarse
    // a clase, no a gestionarlas.
    final gestionando = ref.watch(enModoGestionProvider);

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
      floatingActionButton: (gestionando && academiaId != null)
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
          // En Entrenamiento manda el saludo; en Gestor, un título de
          // pantalla normal, porque «Hoy» es una herramienta de trabajo.
          if (gestionando)
            const TituloPantalla('Hoy')
          else
            const _CabeceraInicio(),
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
                color: AppColors.ink,
                shape: BoxShape.circle,
              ),
              todayDecoration: BoxDecoration(
                color: AppColors.surfaceStrong,
                shape: BoxShape.circle,
              ),
              selectedDecoration: BoxDecoration(
                color: AppColors.ink,
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
          const Divider(height: 1, color: AppColors.line),
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
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: AppColors.subtle),
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
                    if (gestionando) {
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
                      onUnirse: userId == null ? null : () => _unirse(clase),
                      onBorrarse: userId == null
                          ? null
                          : () => _borrarse(clase),
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

/// Encabezado del modo Entrenamiento: marca, saludo y check-in rápido.
class _CabeceraInicio extends ConsumerWidget {
  const _CabeceraInicio();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nombre = ref.watch(currentProfileProvider).value?.nombre;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: AppColors.ink,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Text(
              'I+',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              nombre == null ? '¡Hola!' : '¡Hola, $nombre!',
              style: Theme.of(context).textTheme.headlineMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            onPressed: () => _mostrarQr(context),
            icon: const Icon(Icons.qr_code_2, size: 26),
            tooltip: 'Mostrar mi código de check-in',
            style: IconButton.styleFrom(
              side: const BorderSide(color: AppColors.line),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              minimumSize: const Size(48, 48),
            ),
          ),
        ],
      ),
    );
  }

  void _mostrarQr(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => const Padding(
        padding: EdgeInsets.fromLTRB(24, 0, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Check-in rápido',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            SizedBox(height: 8),
            Text(
              'Enseña este código en recepción para registrar tu asistencia.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.subtle),
            ),
            SizedBox(height: 24),
            Icon(Icons.qr_code_2, size: 180),
            SizedBox(height: 12),
            Text(
              'Pendiente de conectar con el lector de recepción',
              style: TextStyle(fontSize: 12, color: AppColors.subtle),
            ),
          ],
        ),
      ),
    );
  }
}
