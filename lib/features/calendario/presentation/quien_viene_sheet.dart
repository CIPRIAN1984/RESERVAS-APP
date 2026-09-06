import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/color_tokens.dart';
import '../../../core/auth/auth_state.dart';
import '../../../core/models/profile.dart';
import '../../../shared/widgets/pantalla.dart';
import '../../perfil/application/profile_providers.dart';
import '../application/clases_providers.dart';
import '../data/clase_resumen.dart';
import 'mensajes_reserva.dart';

/// «¿Quién viene a esta clase?»: apuntar y quitar a cada miembro de la
/// familia sin salir del calendario.
///
/// Solo aparece cuando el usuario tiene hijos dados de alta. Quien no los
/// tiene ve la tarjeta de siempre, con su único botón: son la inmensa
/// mayoría y no hay por qué complicarles la pantalla.
Future<void> mostrarQuienVieneSheet(BuildContext context, String claseId) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useRootNavigator: true,
    builder: (_) => _QuienVieneSheet(claseId: claseId),
  );
}

class _QuienVieneSheet extends ConsumerStatefulWidget {
  const _QuienVieneSheet({required this.claseId});

  final String claseId;

  @override
  ConsumerState<_QuienVieneSheet> createState() => _QuienVieneSheetState();
}

class _QuienVieneSheetState extends ConsumerState<_QuienVieneSheet> {
  /// Quién tiene una acción en marcha, para no dejar pulsar dos veces.
  String? _ocupado;

  Future<void> _cambiar({
    required ClaseResumen clase,
    required String alumnoId,
    required String nombre,
    required bool reservar,
    required bool esMio,
  }) async {
    setState(() => _ocupado = alumnoId);
    final repo = ref.read(clasesRepositoryProvider);
    // `null` significa «yo» para el servidor: así `reservar_clase` ni se
    // molesta en comprobar la relación de familia.
    final idParaElServidor = esMio ? null : alumnoId;
    try {
      if (reservar) {
        final estado = await repo.unirse(
          claseId: clase.id,
          alumnoId: idParaElServidor,
        );
        _avisar(
          estado == 'espera'
              ? 'Clase completa: $nombre queda en la lista de espera.'
              : '$nombre tiene plaza en esta clase.',
        );
      } else {
        final tardia = await repo.borrarse(
          claseId: clase.id,
          alumnoId: idParaElServidor,
        );
        _avisar(
          tardia
              ? 'Reserva cancelada. Queda registrada como cancelación tardía.'
              : 'Reserva cancelada.',
        );
      }
      // Se recarga la semana entera y no solo esta clase: cancelar puede
      // ascender a alguien de la lista de espera de otra tarjeta.
      ref.invalidate(clasesSemanaProvider);
    } catch (e) {
      _avisar(mensajeReserva(e, nombre: esMio ? null : nombre));
    } finally {
      if (mounted) setState(() => _ocupado = null);
    }
  }

  void _avisar(String texto) {
    if (!mounted) return;
    // La hoja NO se cierra: un padre con dos hijos los apunta a los dos
    // seguidos, y cerrarla tras el primero le obliga a volver a abrirla.
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final miId = ref.watch(currentUserIdProvider);
    final miPerfil = ref.watch(currentProfileProvider).value;
    final hijos = ref.watch(hijosProvider).value ?? const <Profile>[];
    // Se relee del proveedor y no se guarda una copia: tras cada reserva la
    // semana se recarga y la hoja tiene que enseñar el estado nuevo.
    final clase = ref
        .watch(clasesSemanaProvider)
        .value
        ?.where((c) => c.id == widget.claseId)
        .firstOrNull;

    if (clase == null) {
      return const SizedBox(
        height: 160,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final inicio = DateFormat.Hm().format(clase.fechaHoraInicio.toLocal());
    final dia = DateFormat(
      "EEEE d 'de' MMMM",
      'es_ES',
    ).format(clase.fechaHoraInicio.toLocal());

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('¿Quién viene?', style: t.titleLarge),
                    const SizedBox(height: 4),
                    Text(
                      '${clase.titulo} · $dia a las $inicio',
                      style: t.bodySmall?.copyWith(color: AppColors.subtle),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Yo, solo si entreno. Al tutor que solo trae al niño el
              // servidor le rechazaría la reserva, así que ofrecérsela sería
              // enseñarle un botón que no funciona.
              if (miId != null && (miPerfil?.entrena ?? true))
                _FilaPersona(
                  nombre: 'Yo',
                  estado: clase.estadoDe(miId, miId: miId),
                  clase: clase,
                  cargando: _ocupado == miId,
                  bloqueada: _ocupado != null,
                  onCambiar: (reservar) => _cambiar(
                    clase: clase,
                    alumnoId: miId,
                    nombre: 'Tu reserva',
                    reservar: reservar,
                    esMio: true,
                  ),
                ),

              for (final hijo in hijos)
                _FilaPersona(
                  nombre: [
                    hijo.nombre,
                    hijo.apellidos,
                  ].whereType<String>().join(' '),
                  estado: clase.estadoDe(hijo.id, miId: miId),
                  clase: clase,
                  cargando: _ocupado == hijo.id,
                  bloqueada: _ocupado != null,
                  onCambiar: (reservar) => _cambiar(
                    clase: clase,
                    alumnoId: hijo.id,
                    nombre: hijo.nombre,
                    reservar: reservar,
                    esMio: false,
                  ),
                ),

              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  'Cada plaza va a nombre de quien entrena, no del adulto que '
                  'lo trae.',
                  style: t.bodySmall?.copyWith(color: AppColors.subtle),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilaPersona extends StatelessWidget {
  const _FilaPersona({
    required this.nombre,
    required this.estado,
    required this.clase,
    required this.cargando,
    required this.bloqueada,
    required this.onCambiar,
  });

  final String nombre;

  /// `inscrito`, `espera` o `null` si esta persona no tiene nada aquí.
  final String? estado;
  final ClaseResumen clase;
  final bool cargando;

  /// Hay otra acción en marcha: se apagan los demás botones para que no se
  /// crucen dos reservas sobre la misma clase.
  final bool bloqueada;

  /// `true` para reservar, `false` para cancelar.
  final ValueChanged<bool> onCambiar;

  @override
  Widget build(BuildContext context) {
    final inscrito = estado == 'inscrito';
    final enEspera = estado == 'espera';
    final tienePlaza = inscrito || enEspera;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TarjetaFila(
        titulo: nombre,
        estado: inscrito
            ? const PastillaEstado.exito('Inscrito', icono: Icons.check)
            : enEspera
            ? const PastillaEstado.aviso(
                'En espera',
                icono: Icons.hourglass_top,
              )
            : null,
        detalle: tienePlaza ? null : 'Sin plaza en esta clase',
        accion: _boton(tienePlaza, enEspera),
      ),
    );
  }

  Widget _boton(bool tienePlaza, bool enEspera) {
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

    if (tienePlaza) {
      return OutlinedButton(
        onPressed: bloqueada ? null : () => onCambiar(false),
        child: Text(enEspera ? 'Salir de la espera' : 'Cancelar la reserva'),
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
      onPressed: bloqueada ? null : () => onCambiar(true),
      child: Text(
        clase.aforoCompleto ? 'Apuntar a la lista de espera' : 'Reservar plaza',
      ),
    );
  }
}
