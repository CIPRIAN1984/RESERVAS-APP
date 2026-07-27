import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/color_tokens.dart';
import '../../../core/models/profile.dart';
import '../../../core/utils/error_messages.dart';
import '../application/equipo_providers.dart';

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

  @override
  Widget build(BuildContext context) {
    final miembrosAsync = ref.watch(miembrosEquipoProvider);

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
                ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
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
                        subtitle: Text(
                          miembro.isDueno
                              ? 'Dueño'
                              : miembro.isProfesor
                              ? 'Profesor'
                              : 'Alumno',
                        ),
                        trailing: gestionable
                            ? actualizando
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : TextButton(
                                      onPressed: _actualizandoId == null
                                          ? () => _cambiarRol(miembro)
                                          : null,
                                      child: Text(
                                        miembro.isProfesor
                                            ? 'Hacer alumno'
                                            : 'Hacer profesor',
                                      ),
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
