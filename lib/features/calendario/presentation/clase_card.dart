import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/color_tokens.dart';
import '../../../shared/widgets/pantalla.dart';
import '../data/clase_resumen.dart';

/// Una sesión concreta en el listado del día.
///
/// Qué acciones trae depende del **modo**, no del rol: `onUnirse`/`onBorrarse`
/// en modo Entrenamiento (reservar plaza), `onTap` en modo Gestor (lleva a la
/// lista de asistentes). Un dueño ve una u otra según lo que esté haciendo.
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
    final t = Theme.of(context).textTheme;
    final inicio = DateFormat.Hm().format(clase.fechaHoraInicio.toLocal());
    final fin = DateFormat.Hm().format(clase.fechaHoraFin.toLocal());
    final hayAccion = onUnirse != null || onBorrarse != null;
    final libres = clase.aforoMaximo - clase.inscritosCount;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Marca de la academia, como en el prototipo.
                  Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      color: AppColors.ink,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      'I+',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          clase.titulo,
                          style: t.titleMedium,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$inicio – $fin',
                          style: t.bodyMedium?.copyWith(
                            color: AppColors.subtle,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (clase.cancelada)
                    const PastillaEstado.error('Cancelada')
                  else if (clase.cerrada)
                    const PastillaEstado.aviso('Cerrada')
                  else if (clase.tieneReservaActiva)
                    clase.enListaEspera
                        ? const PastillaEstado.aviso(
                            'En espera',
                            icono: Icons.hourglass_top,
                          )
                        : const PastillaEstado.exito(
                            'Inscrito',
                            icono: Icons.check,
                          ),
                ],
              ),
              const SizedBox(height: 14),

              // Aforo e instructor, con iconos como en MAAT.
              Row(
                children: [
                  _Dato(
                    icono: Icons.groups_outlined,
                    texto:
                        '${clase.inscritosCount}/${clase.aforoMaximo}'
                        ' inscritos',
                    destacado: clase.aforoCompleto,
                  ),
                  const SizedBox(width: 20),
                  Flexible(
                    child: _Dato(
                      icono: Icons.person_outline,
                      texto: clase.profesorNombre,
                    ),
                  ),
                ],
              ),

              if (hayAccion) ...[
                const SizedBox(height: 14),
                _Accion(
                  clase: clase,
                  cargando: loadingAccion,
                  onUnirse: onUnirse,
                  onBorrarse: onBorrarse,
                ),
                if (!clase.aforoCompleto && !clase.tieneReservaActiva) ...[
                  const SizedBox(height: 10),
                  Center(
                    child: Text(
                      libres == 1 ? 'Queda 1 plaza' : 'Quedan $libres plazas',
                      style: t.labelSmall,
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Dato extends StatelessWidget {
  const _Dato({
    required this.icono,
    required this.texto,
    this.destacado = false,
  });

  final IconData icono;
  final String texto;
  final bool destacado;

  @override
  Widget build(BuildContext context) {
    final color = destacado ? AppColors.warningFg : AppColors.subtle;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icono, size: 17, color: color),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            texto,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: color),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _Accion extends StatelessWidget {
  const _Accion({
    required this.clase,
    required this.cargando,
    this.onUnirse,
    this.onBorrarse,
  });

  final ClaseResumen clase;
  final bool cargando;
  final VoidCallback? onUnirse;
  final VoidCallback? onBorrarse;

  @override
  Widget build(BuildContext context) {
    if (cargando) {
      return const SizedBox(
        height: 52,
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.4),
          ),
        ),
      );
    }

    if (clase.tieneReservaActiva) {
      return OutlinedButton(
        onPressed: onBorrarse,
        child: Text(
          clase.enListaEspera
              ? 'Salir de la lista de espera'
              : 'Cancelar reserva',
        ),
      );
    }

    if (!clase.activa) {
      return OutlinedButton(
        onPressed: null,
        child: Text(
          clase.cancelada ? 'Clase cancelada' : 'Cerrada a nuevas reservas',
        ),
      );
    }

    return ElevatedButton(
      onPressed: onUnirse,
      child: Text(
        clase.aforoCompleto
            ? 'Apuntarme a la lista de espera'
            : 'Reservar plaza',
      ),
    );
  }
}
