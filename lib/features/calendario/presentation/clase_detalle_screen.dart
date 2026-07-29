import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/color_tokens.dart';
import '../../../core/auth/auth_state.dart';
import '../application/clases_providers.dart';
import '../data/clase_resumen.dart';
import '../data/clases_repository.dart';
import '../data/inscrito_alumno.dart';

/// Profesor/Dueño/Administrador view of a class: confirmed roster, attendance
/// and the FIFO waitlist that the backend promotes automatically.
class ClaseDetalleScreen extends ConsumerStatefulWidget {
  const ClaseDetalleScreen({required this.clase, super.key});

  final ClaseResumen clase;

  @override
  ConsumerState<ClaseDetalleScreen> createState() => _ClaseDetalleScreenState();
}

class _ClaseDetalleScreenState extends ConsumerState<ClaseDetalleScreen> {
  late Future<ParticipantesClase> _future;
  final Set<String> _marcando = {};

  @override
  void initState() {
    super.initState();
    _future = ref
        .read(clasesRepositoryProvider)
        .listarParticipantes(widget.clase.id);
  }

  void _recargar() {
    setState(() {
      _future = ref
          .read(clasesRepositoryProvider)
          .listarParticipantes(widget.clase.id);
    });
  }

  Future<void> _marcarAsistencia(
    InscritoAlumno alumno,
    String validadoPor,
  ) async {
    setState(() => _marcando.add(alumno.alumnoId));
    try {
      await ref
          .read(clasesRepositoryProvider)
          .marcarAsistencia(
            claseId: widget.clase.id,
            alumnoId: alumno.alumnoId,
            validadoPor: validadoPor,
          );
      _recargar();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se ha podido validar la asistencia.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _marcando.remove(alumno.alumnoId));
    }
  }

  Widget _buildInscrito(
    BuildContext context,
    InscritoAlumno alumno,
    String? userId,
  ) {
    final marcando = _marcando.contains(alumno.alumnoId);
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: AppColors.surface,
        backgroundImage: alumno.fotoUrl != null
            ? CachedNetworkImageProvider(alumno.fotoUrl!)
            : null,
        child: alumno.fotoUrl == null
            ? const Icon(Icons.person, color: AppColors.subtle)
            : null,
      ),
      title: Text(alumno.nombreCompleto),
      subtitle: alumno.cinturon != null
          ? Text('Cinturón ${alumno.cinturon}')
          : null,
      trailing: alumno.asistenciaValidada
          ? const Icon(Icons.check_circle, color: AppColors.successFg)
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
  }

  Widget _buildEspera(InscritoAlumno alumno, int posicion) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: AppColors.surface,
        child: Text('$posicion'),
      ),
      title: Text(alumno.nombreCompleto),
      subtitle: Text(
        alumno.cinturon == null
            ? 'Lista de espera'
            : 'Lista de espera · Cinturón ${alumno.cinturon}',
      ),
      trailing: const Icon(Icons.schedule, color: AppColors.warningFg),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(currentUserIdProvider);
    final horario =
        '${DateFormat.Hm().format(widget.clase.fechaHoraInicio.toLocal())} - ${DateFormat.Hm().format(widget.clase.fechaHoraFin.toLocal())}';

    return Scaffold(
      appBar: AppBar(title: Text(widget.clase.titulo)),
      body: FutureBuilder<ParticipantesClase>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'No se han podido cargar los participantes.',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            );
          }

          final participantes =
              snapshot.data ??
              const ParticipantesClase(inscritos: [], listaEspera: []);
          final inscritos = participantes.inscritos;
          final listaEspera = participantes.listaEspera;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      horario,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${inscritos.length}/${widget.clase.aforoMaximo} confirmados · ${listaEspera.length} en espera',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.subtle,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.line),
              Expanded(
                child: inscritos.isEmpty && listaEspera.isEmpty
                    ? Center(
                        child: Text(
                          'Todavía no hay participantes.',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: AppColors.subtle),
                        ),
                      )
                    : ListView(
                        children: [
                          const _SectionTitle(title: 'Confirmados'),
                          if (inscritos.isEmpty)
                            const ListTile(
                              title: Text('No hay plazas confirmadas.'),
                            )
                          else
                            for (final alumno in inscritos)
                              _buildInscrito(context, alumno, userId),
                          if (listaEspera.isNotEmpty) ...[
                            const Divider(height: 24, color: AppColors.line),
                            const _SectionTitle(title: 'Lista de espera'),
                            for (var i = 0; i < listaEspera.length; i++)
                              _buildEspera(listaEspera[i], i + 1),
                          ],
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: AppColors.subtle,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
