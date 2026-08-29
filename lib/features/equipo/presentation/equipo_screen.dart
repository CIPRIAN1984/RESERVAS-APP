import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/color_tokens.dart';
import '../../../core/models/profile.dart';
import '../../../core/utils/error_messages.dart';
import '../../../shared/widgets/pantalla.dart';
import '../application/equipo_providers.dart';
import 'dar_cuota_sheet.dart';
import 'iniciar_prueba_sheet.dart';
import 'pausar_cuota_sheet.dart';

class EquipoScreen extends ConsumerStatefulWidget {
  const EquipoScreen({super.key});

  @override
  ConsumerState<EquipoScreen> createState() => _EquipoScreenState();
}

class _EquipoScreenState extends ConsumerState<EquipoScreen> {
  String _busqueda = '';
  String? _actualizandoId;

  Future<void> _cambiarRol(Profile miembro) async {
    final nuevoRol = miembro.isProfesor ? 'alumno' : 'profesor';
    final accion = miembro.isProfesor ? 'devolver a Alumno' : 'hacer Profesor';
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$accion a ${miembro.nombre}'),
        content: Text(
          miembro.isProfesor
              ? 'Dejará de poder crear clases y gestionar asistencias.'
              : 'Podrá crear clases y gestionar asistencias de la academia.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    if (confirmado != true || !mounted) return;

    setState(() => _actualizandoId = miembro.id);
    try {
      await ref
          .read(equipoRepositoryProvider)
          .cambiarRol(miembroId: miembro.id, nuevoRol: nuevoRol);
      ref.invalidate(miembrosEquipoProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Rol de ${miembro.nombre} actualizado.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              mensajeErrorAmigable(
                error,
                generico: 'No se ha podido actualizar el rol.',
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _actualizandoId = null);
    }
  }

  Future<void> _darCuota(Profile alumno) async {
    final hecho = await mostrarDarCuota(context, alumno);
    if (hecho && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cuota registrada para ${alumno.nombre}.')),
      );
    }
  }

  Future<void> _iniciarPrueba(Profile alumno) async {
    final hecho = await mostrarIniciarPrueba(context, alumno);
    if (hecho && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Prueba de 1 día iniciada para ${alumno.nombre}.'),
        ),
      );
    }
  }

  Future<void> _pausarCuota(Profile alumno, String suscripcionId) async {
    final hecho = await mostrarPausarCuota(context, alumno, suscripcionId);
    if (hecho && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cuota de ${alumno.nombre} pausada.')),
      );
    }
  }

  Future<void> _reanudarCuota(Profile alumno, String suscripcionId) async {
    setState(() => _actualizandoId = alumno.id);
    try {
      await ref.read(equipoRepositoryProvider).reanudarCuota(suscripcionId);
      ref.invalidate(cuotasActivasProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cuota de ${alumno.nombre} reanudada.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              mensajeErrorAmigable(
                error,
                generico: 'No se ha podido reanudar la cuota.',
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _actualizandoId = null);
    }
  }

  Future<void> _retirarCuota(Profile alumno, String suscripcionId) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Retirar la cuota de ${alumno.nombre}'),
        content: const Text(
          'Dejará de poder reservar clases hasta que vuelva a pagar.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Retirar'),
          ),
        ],
      ),
    );
    if (confirmado != true || !mounted) return;

    setState(() => _actualizandoId = alumno.id);
    try {
      await ref
          .read(equipoRepositoryProvider)
          .retirarCuotaEfectivo(suscripcionId);
      ref.invalidate(cuotasActivasProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cuota de ${alumno.nombre} retirada.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              mensajeErrorAmigable(
                error,
                generico: 'No se ha podido retirar la cuota.',
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _actualizandoId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final miembrosAsync = ref.watch(miembrosEquipoProvider);
    // Una sola consulta para toda la academia: con 166 alumnos, una por
    // fila pondría la lista de rodillas.
    final cuotas = ref.watch(cuotasActivasProvider).value ?? const {};

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            children: [
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Buscar miembro',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (value) =>
                    setState(() => _busqueda = value.trim().toLowerCase()),
              ),
              const SizedBox(height: 12),
              Text(
                'Los nuevos miembros se registran primero como Alumnos. '
                'Desde aquí puedes asignar o retirar el rol Profesor.',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.subtle),
              ),
            ],
          ),
        ),
        Expanded(
          child: miembrosAsync.when(
            data: (miembros) {
              final visibles = miembros.where((miembro) {
                if (_busqueda.isEmpty) return true;
                final nombreCompleto =
                    '${miembro.nombre} ${miembro.apellidos ?? ''} '
                            '${miembro.rol}'
                        .toLowerCase();
                return nombreCompleto.contains(_busqueda);
              }).toList();

              if (visibles.isEmpty) {
                return const Center(
                  child: Text('No hay miembros que mostrar.'),
                );
              }

              return RefreshIndicator(
                onRefresh: () async =>
                    ref.refresh(miembrosEquipoProvider.future),
                child: ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  itemCount: visibles.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final miembro = visibles[index];
                    final gestionable = miembro.isAlumno || miembro.isProfesor;
                    final actualizando = _actualizandoId == miembro.id;
                    final cuota = cuotas[miembro.id];
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Text(
                            miembro.nombre.characters.first.toUpperCase(),
                          ),
                        ),
                        title: Text(
                          [
                            miembro.nombre,
                            if (miembro.apellidos?.isNotEmpty ?? false)
                              miembro.apellidos!,
                          ].join(' '),
                        ),
                        // Wrap y no Row: con nombres largos o pantallas
                        // estrechas, la pastilla se salía por la derecha.
                        subtitle: Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              miembro.isDueno
                                  ? 'Dueño'
                                  : miembro.isProfesor
                                  ? 'Profesor'
                                  : 'Alumno',
                            ),
                            // Solo el Alumno necesita cuota para reservar.
                            if (miembro.isAlumno)
                              switch (cuota?.estado) {
                                null => const PastillaEstado.error('Sin cuota'),
                                'prueba' => const PastillaEstado.info('Prueba'),
                                'pausada' => const PastillaEstado.aviso(
                                  'Pausada',
                                ),
                                _ => PastillaEstado.exito(
                                  cuota!.efectivo ? 'Efectivo' : 'Al corriente',
                                ),
                              },
                          ],
                        ),
                        trailing: actualizando
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : gestionable
                            ? _MenuMiembro(
                                miembro: miembro,
                                cuota: cuota,
                                habilitado: _actualizandoId == null,
                                onCambiarRol: () => _cambiarRol(miembro),
                                onDarCuota: () => _darCuota(miembro),
                                onIniciarPrueba: cuota == null
                                    ? () => _iniciarPrueba(miembro)
                                    : null,
                                onPausarCuota:
                                    cuota != null &&
                                        cuota.efectivo &&
                                        cuota.estado == 'activa'
                                    ? () => _pausarCuota(miembro, cuota.id)
                                    : null,
                                onReanudarCuota:
                                    cuota != null &&
                                        cuota.efectivo &&
                                        cuota.estado == 'pausada'
                                    ? () => _reanudarCuota(miembro, cuota.id)
                                    : null,
                                onRetirarCuota: cuota != null && cuota.efectivo
                                    ? () => _retirarCuota(miembro, cuota.id)
                                    : null,
                              )
                            : const Chip(label: Text('Propietario')),
                      ),
                    );
                  },
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('No se pudo cargar el equipo.'),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () => ref.invalidate(miembrosEquipoProvider),
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Acciones sobre un miembro. Van en un menú y no sueltas en la fila porque
/// son tres y la fila se volvía ilegible en un móvil.
class _MenuMiembro extends StatelessWidget {
  const _MenuMiembro({
    required this.miembro,
    required this.cuota,
    required this.habilitado,
    required this.onCambiarRol,
    required this.onDarCuota,
    required this.onIniciarPrueba,
    required this.onPausarCuota,
    required this.onReanudarCuota,
    required this.onRetirarCuota,
  });

  final Profile miembro;
  final ({String id, String tarifa, bool efectivo, String estado})? cuota;
  final bool habilitado;
  final VoidCallback onCambiarRol;
  final VoidCallback onDarCuota;
  final VoidCallback? onIniciarPrueba;
  final VoidCallback? onPausarCuota;
  final VoidCallback? onReanudarCuota;
  final VoidCallback? onRetirarCuota;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<VoidCallback>(
      enabled: habilitado,
      tooltip: 'Acciones sobre ${miembro.nombre}',
      onSelected: (accion) => accion(),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: onCambiarRol,
          child: Text(
            miembro.isProfesor ? 'Devolver a alumno' : 'Hacer profesor',
          ),
        ),
        if (miembro.isAlumno)
          PopupMenuItem(
            value: onDarCuota,
            child: Text(cuota == null ? 'Registrar cobro' : 'Renovar cuota'),
          ),
        if (onIniciarPrueba != null)
          PopupMenuItem(
            value: onIniciarPrueba,
            child: const Text('Iniciar prueba (1 día)'),
          ),
        if (onPausarCuota != null)
          PopupMenuItem(
            value: onPausarCuota,
            child: const Text('Pausar cuota'),
          ),
        if (onReanudarCuota != null)
          PopupMenuItem(
            value: onReanudarCuota,
            child: const Text('Reanudar cuota'),
          ),
        if (onRetirarCuota != null)
          PopupMenuItem(
            value: onRetirarCuota,
            child: const Text('Retirar cuota'),
          ),
      ],
    );
  }
}
