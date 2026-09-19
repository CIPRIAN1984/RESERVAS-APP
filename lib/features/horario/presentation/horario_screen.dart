import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/color_tokens.dart';
import '../../../core/auth/auth_state.dart';
import '../../../core/utils/error_messages.dart';
import '../../../shared/widgets/pantalla.dart';
import '../application/horario_providers.dart';
import '../data/plantilla_clase.dart';
import 'crear_plantilla_screen.dart';

/// El horario fijo de la academia: los huecos que se repiten cada semana
/// solos, sin que haya que volver a crearlos cada pocas semanas.
///
/// Esto **no** es el calendario del día a día (eso sigue en Hoy): aquí se
/// decide la plantilla — «BJJ los lunes y miércoles a las 19:00» — y el
/// servidor la convierte en clases de verdad cada semana. Cancelar un día
/// suelto o cambiar una clase concreta se sigue haciendo desde el
/// calendario, no desde aquí.
class HorarioScreen extends ConsumerWidget {
  const HorarioScreen({super.key});

  Future<void> _alternarActivo(
    WidgetRef ref,
    String academiaId,
    PlantillaClase plantilla,
  ) async {
    try {
      await ref
          .read(horarioRepositoryProvider)
          .alternarActivo(plantilla.id, !plantilla.activo);
      ref.invalidate(plantillasProvider(academiaId));
    } catch (_) {
      // El interruptor vuelve solo a su sitio si falla, al no haber
      // cambiado el estado que lee la lista.
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider).value;
    final userId = ref.watch(currentUserIdProvider);

    if (profile == null || profile.academiaId == null || userId == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final academiaId = profile.academiaId!;
    final plantillasAsync = ref.watch(plantillasProvider(academiaId));

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => CrearPlantillaScreen(
                academiaId: academiaId,
                profesorId: userId,
              ),
            ),
          );
          ref.invalidate(plantillasProvider(academiaId));
        },
        icon: const Icon(Icons.add),
        label: const Text('Horario fijo'),
      ),
      body: plantillasAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(
          child: Text(
            mensajeErrorAmigable(
              e,
              generico: 'No se ha podido cargar el horario.',
            ),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
        data: (plantillas) {
          if (plantillas.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.calendar_month_outlined,
                      size: 48,
                      color: AppColors.disabled,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Todavía no tienes ningún horario fijo. Crea el '
                      'primero y se repetirá solo cada semana.',
                      textAlign: TextAlign.center,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: AppColors.subtle),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(
              16,
              16,
              16,
              espacioBotonesFlotantes,
            ),
            itemCount: plantillas.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final plantilla = plantillas[index];
              return TarjetaFila(
                titulo: plantilla.titulo,
                detalle:
                    '${nombresDias[plantilla.diaSemana]} · '
                    '${rangoHorario(plantilla.horaInicio, plantilla.duracionMin)}\n'
                    'Aforo ${plantilla.aforoMaximo} · '
                    'Imparte ${plantilla.profesorNombre}',
                estado: plantilla.activo
                    ? null
                    : const PastillaEstado.aviso('Pausado'),
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => CrearPlantillaScreen(
                        academiaId: academiaId,
                        profesorId: userId,
                        plantilla: plantilla,
                      ),
                    ),
                  );
                  ref.invalidate(plantillasProvider(academiaId));
                },
                accion: OutlinedButton(
                  onPressed: () => _alternarActivo(ref, academiaId, plantilla),
                  child: Text(plantilla.activo ? 'Pausar' : 'Reanudar'),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
