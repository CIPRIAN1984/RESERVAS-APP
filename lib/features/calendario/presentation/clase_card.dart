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
    this.onQuienViene,
    this.nombrePorAlumnoId = const {},
    this.onConfirmarTodos,
    this.loadingAccion = false,
    this.confirmandoTodos = false,
    super.key,
  });

  final ClaseResumen clase;
  final VoidCallback? onTap;
  final VoidCallback? onUnirse;
  final VoidCallback? onBorrarse;

  /// Solo para quien tiene hijos dados de alta: en vez del botón de siempre,
  /// abre la hoja «¿Quién viene?», donde se apunta y se quita a cada uno.
  /// Cuando es `null` la tarjeta se comporta exactamente igual que antes de
  /// que existieran las familias.
  final VoidCallback? onQuienViene;

  /// Cómo se llama cada hijo, para poder escribir «Nico tiene plaza» en vez
  /// de un uuid. Lo que no esté aquí simplemente no se nombra.
  final Map<String, String> nombrePorAlumnoId;

  /// Modo Gestor: confirma de golpe la asistencia de todos los inscritos
  /// sin validar, sin entrar en el detalle de la clase.
  final VoidCallback? onConfirmarTodos;
  final bool loadingAccion;
  final bool confirmandoTodos;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final inicio = DateFormat.Hm().format(clase.fechaHoraInicio.toLocal());
    final fin = DateFormat.Hm().format(clase.fechaHoraFin.toLocal());
    final hayAccion =
        onUnirse != null || onBorrarse != null || onQuienViene != null;
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
                  // Con familia, mi estado baja a la fila de abajo junto al
                  // de los hijos: aquí arriba, suelto, un «INSCRITO» al lado
                  // de «NICO» y «LUCÍA» no dice de quién es.
                  else if (clase.tieneReservaActiva && onQuienViene == null)
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

              // Quién de la familia tiene plaza, yo incluido y con mi nombre.
              // Sin esto un padre apunta al niño y la tarjeta no cambia:
              // parece que no ha pasado nada.
              if (onQuienViene != null &&
                  (clase.tieneReservaActiva ||
                      clase.reservasFamilia.isNotEmpty)) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (clase.tieneReservaActiva)
                      _PastillaDeAlguien(
                        nombre: 'Tú',
                        enEspera: clase.enListaEspera,
                      ),
                    for (final r in clase.reservasFamilia)
                      _PastillaDeAlguien(
                        nombre: nombrePorAlumnoId[r.alumnoId] ?? 'Tu hijo',
                        enEspera: r.estado == 'espera',
                      ),
                  ],
                ),
              ],

              if (hayAccion) ...[
                const SizedBox(height: 14),
                _Accion(
                  clase: clase,
                  cargando: loadingAccion,
                  onUnirse: onUnirse,
                  onBorrarse: onBorrarse,
                  onQuienViene: onQuienViene,
                ),
                if (onQuienViene == null &&
                    !clase.aforoCompleto &&
                    !clase.tieneReservaActiva) ...[
                  const SizedBox(height: 10),
                  Center(
                    child: Text(
                      libres == 1 ? 'Queda 1 plaza' : 'Quedan $libres plazas',
                      style: t.labelSmall,
                    ),
                  ),
                ],
              ],
              if (onConfirmarTodos != null &&
                  clase.pendientesConfirmar > 0) ...[
                const SizedBox(height: 14),
                confirmandoTodos
                    ? const SizedBox(
                        height: 52,
                        child: Center(
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.4),
                          ),
                        ),
                      )
                    : OutlinedButton(
                        onPressed: onConfirmarTodos,
                        child: Text(
                          clase.pendientesConfirmar == 1
                              ? 'Confirmar 1 alumno'
                              : 'Confirmar ${clase.pendientesConfirmar} alumnos',
                        ),
                      ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// «NICO» si tiene plaza, «NICO · EN ESPERA» si espera sitio. Solo aparece
/// en las tarjetas de quien tiene familia: con una sola persona basta con la
/// pastilla de arriba, que ya se sabe de quién es.
class _PastillaDeAlguien extends StatelessWidget {
  const _PastillaDeAlguien({required this.nombre, required this.enEspera});

  final String nombre;
  final bool enEspera;

  @override
  Widget build(BuildContext context) {
    return enEspera
        ? PastillaEstado.aviso(
            '$nombre · en espera',
            icono: Icons.hourglass_top,
          )
        : PastillaEstado.exito(nombre, icono: Icons.check);
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
    this.onQuienViene,
  });

  final ClaseResumen clase;
  final bool cargando;
  final VoidCallback? onUnirse;
  final VoidCallback? onBorrarse;
  final VoidCallback? onQuienViene;

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

    // Con hijos dados de alta, un solo botón no puede decir la verdad: yo
    // puedo tener plaza y el niño no, o al revés. Se abre la hoja y allí cada
    // uno tiene la suya.
    if (onQuienViene != null) {
      final alguienDentro =
          clase.tieneReservaActiva || clase.reservasFamilia.isNotEmpty;
      return alguienDentro
          ? OutlinedButton(
              onPressed: onQuienViene,
              child: const Text('Cambiar quién viene'),
            )
          : ElevatedButton(
              onPressed: onQuienViene,
              child: const Text('Reservar plaza'),
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
