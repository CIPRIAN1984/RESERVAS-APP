import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/color_tokens.dart';
import '../data/clase_resumen.dart';

/// Displays one class occurrence. `onUnirse`/`onBorrarse` are only passed for
/// Alumno (shows the join/leave action); `onTap` is only passed for
/// Profesor/Dueño/Administrador (navigates to the roster/attendance screen).
class ClaseCard extends StatelessWidget {
  const ClaseCard({
    required this.clase,
    this.onTap,
    this.onUnirse,
    this.onBorrarse,
    this.loadingAccion = false,
    super.key,
  });

  final ClaseResumen clase;
  final VoidCallback? onTap;
  final VoidCallback? onUnirse;
  final VoidCallback? onBorrarse;
  final bool loadingAccion;

  @override
  Widget build(BuildContext context) {
    final horario =
        '${DateFormat.Hm().format(clase.fechaHoraInicio.toLocal())} - ${DateFormat.Hm().format(clase.fechaHoraFin.toLocal())}';

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      horario,
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      clase.titulo,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Prof. ${clase.profesorNombre}',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: AppColors.subtle),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${clase.inscritosCount}/${clase.aforoMaximo} inscritos',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: clase.aforoCompleto
                            ? AppColors.warningFg
                            : AppColors.subtle,
                      ),
                    ),
                  ],
                ),
              ),
              if (onUnirse != null || onBorrarse != null)
                _buildAccionAlumno(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAccionAlumno(BuildContext context) {
    if (loadingAccion) {
      return const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    if (clase.tieneReservaActiva) {
      return OutlinedButton(
        onPressed: onBorrarse,
        child: Text(clase.enListaEspera ? 'Salir de espera' : 'Cancelar'),
      );
    }
    return ElevatedButton(
      onPressed: onUnirse,
      child: Text(clase.aforoCompleto ? 'Lista de espera' : 'Reservar'),
    );
  }
}
