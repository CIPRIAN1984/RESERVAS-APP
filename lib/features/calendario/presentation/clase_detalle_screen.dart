import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/color_tokens.dart';
import '../../../core/auth/auth_state.dart';
import '../application/clases_providers.dart';
import '../data/clase_resumen.dart';
import '../data/inscrito_alumno.dart';

/// Profesor/Dueño/Administrador view of a class: roster of enrolled students
/// with a one-way "validar asistencia" action per student (module 1 —
/// this is what feeds the ranking in module 2).
class ClaseDetalleScreen extends ConsumerStatefulWidget {
  const ClaseDetalleScreen({required this.clase, super.key});

  final ClaseResumen clase;

  @override
  ConsumerState<ClaseDetalleScreen> createState() => _ClaseDetalleScreenState();
}

class _ClaseDetalleScreenState extends ConsumerState<ClaseDetalleScreen> {
  late Future<List<InscritoAlumno>> _future;
  final Set<String> _marcando = {};

  @override
  void initState() {
    super.initState();
    _future = ref.read(clasesRepositoryProvider).listarInscritos(widget.clase.id);
  }

  void _recargar() {
    setState(() {
      _future = ref.read(clasesRepositoryProvider).listarInscritos(widget.clase.id);
    });
  }

  Future<void> _marcarAsistencia(InscritoAlumno alumno, String validadoPor) async {
    setState(() => _marcando.add(alumno.alumnoId));
    try {
      await ref.read(clasesRepositoryProvider).marcarAsistencia(
            claseId: widget.clase.id,
            alumnoId: alumno.alumnoId,
            validadoPor: validadoPor,
          );
      _recargar();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se ha podido validar la asistencia.')),
        );
      }
    } finally {
      if (mounted) setState(() => _marcando.remove(alumno.alumnoId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(currentUserIdProvider);
    final horario =
        '${DateFormat.Hm().format(widget.clase.fechaHoraInicio.toLocal())} - ${DateFormat.Hm().format(widget.clase.fechaHoraFin.toLocal())}';

    return Scaffold(
      appBar: AppBar(title: Text(widget.clase.titulo)),
      body: FutureBuilder<List<InscritoAlumno>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('No se ha podido cargar la lista de inscritos.',
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            );
          }
          final inscritos = snapshot.data ?? [];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(horario, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      '${inscritos.length}/${widget.clase.aforoMaximo} inscritos',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.divider),
              Expanded(
                child: inscritos.isEmpty
                    ? Center(
                        child: Text(
                          'Todavía no hay inscritos.',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: AppColors.textSecondary),
                        ),
                      )
                    : ListView.builder(
                        itemCount: inscritos.length,
                        itemBuilder: (context, index) {
                          final alumno = inscritos[index];
                          final marcando = _marcando.contains(alumno.alumnoId);
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppColors.surfaceElevated,
                              backgroundImage: alumno.fotoUrl != null
                                  ? CachedNetworkImageProvider(alumno.fotoUrl!)
                                  : null,
                              child: alumno.fotoUrl == null
                                  ? const Icon(Icons.person, color: AppColors.textSecondary)
                                  : null,
                            ),
                            title: Text(alumno.nombreCompleto),
                            subtitle: alumno.cinturon != null
                                ? Text('Cinturón ${alumno.cinturon}')
                                : null,
                            trailing: alumno.asistenciaValidada
                                ? const Icon(Icons.check_circle, color: AppColors.success)
                                : marcando
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : OutlinedButton(
                                        onPressed: userId == null
                                            ? null
                                            : () => _marcarAsistencia(alumno, userId),
                                        child: const Text('Validar'),
                                      ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
