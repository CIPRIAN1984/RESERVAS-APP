import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme/color_tokens.dart';
import '../../../core/auth/auth_state.dart';
import '../application/progreso_providers.dart';
import '../data/media_tecnica.dart';
import '../data/progreso_repository.dart';
import '../data/tecnica.dart';

class TecnicaDetalleScreen extends ConsumerStatefulWidget {
  const TecnicaDetalleScreen({required this.tecnica, super.key});

  final Tecnica tecnica;

  @override
  ConsumerState<TecnicaDetalleScreen> createState() =>
      _TecnicaDetalleScreenState();
}

class _TecnicaDetalleScreenState extends ConsumerState<TecnicaDetalleScreen> {
  late Future<List<MediaTecnica>> _mediaFuture;
  late Future<List<AlumnoOption>> _alumnosFuture;

  final _urlController = TextEditingController();
  String _tipoMedia = 'video';
  String? _alumnoSeleccionado;
  String _estadoSeleccionado = 'en_proceso';
  bool _guardandoMedia = false;
  bool _guardandoProgreso = false;

  @override
  void initState() {
    super.initState();
    _mediaFuture = ref
        .read(progresoRepositoryProvider)
        .listarMedia(widget.tecnica.id);
    _alumnosFuture = ref
        .read(progresoRepositoryProvider)
        .listarAlumnos(widget.tecnica.academiaId);
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  void _recargarMedia() {
    setState(() {
      _mediaFuture = ref
          .read(progresoRepositoryProvider)
          .listarMedia(widget.tecnica.id);
    });
  }

  Future<void> _agregarMedia(String subidoPor) async {
    if (_urlController.text.trim().isEmpty) return;
    setState(() => _guardandoMedia = true);
    try {
      await ref
          .read(progresoRepositoryProvider)
          .agregarMedia(
            tecnicaId: widget.tecnica.id,
            tipo: _tipoMedia,
            url: _urlController.text.trim(),
            subidoPor: subidoPor,
          );
      _urlController.clear();
      _recargarMedia();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se ha podido añadir el material.')),
        );
      }
    } finally {
      if (mounted) setState(() => _guardandoMedia = false);
    }
  }

  Future<void> _guardarProgreso() async {
    if (_alumnoSeleccionado == null) return;
    setState(() => _guardandoProgreso = true);
    try {
      await ref
          .read(progresoRepositoryProvider)
          .marcarProgreso(
            alumnoId: _alumnoSeleccionado!,
            tecnicaId: widget.tecnica.id,
            estado: _estadoSeleccionado,
          );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Progreso actualizado.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se ha podido actualizar el progreso.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _guardandoProgreso = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentProfileProvider).value;
    final userId = ref.watch(currentUserIdProvider);
    final esAlumno = profile?.isAlumno ?? false;
    final puedeGestionar =
        profile != null &&
        (profile.isProfesor || profile.isDueno || profile.isAdministrador);
    final miProgreso = ref.watch(miProgresoProvider).value;
    String? miEstado;
    if (esAlumno && miProgreso != null) {
      miEstado = miProgreso[widget.tecnica.id];
    }

    return Scaffold(
      appBar: AppBar(title: Text(widget.tecnica.nombre)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Wrap(
              spacing: 8,
              children: [
                Chip(
                  label: Text(
                    nombreCinturones[widget.tecnica.cinturon] ??
                        widget.tecnica.cinturon,
                  ),
                ),
                if (miEstado != null)
                  Chip(label: Text(_etiquetaEstado(miEstado))),
              ],
            ),
            if (widget.tecnica.descripcion != null) ...[
              const SizedBox(height: 16),
              Text(
                widget.tecnica.descripcion!,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
            const SizedBox(height: 24),
            Text('Material', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            FutureBuilder<List<MediaTecnica>>(
              future: _mediaFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final media = snapshot.data ?? [];
                if (media.isEmpty) {
                  return Text(
                    'Todavía no hay material enlazado.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  );
                }
                return Column(
                  children: [
                    for (final m in media)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          m.tipo == 'video'
                              ? Icons.play_circle_outline
                              : Icons.image_outlined,
                        ),
                        title: Text(
                          m.url,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => launchUrl(
                          Uri.parse(m.url),
                          mode: LaunchMode.externalApplication,
                        ),
                      ),
                  ],
                );
              },
            ),
            if (puedeGestionar) ...[
              const SizedBox(height: 32),
              Text(
                'Añadir material',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  DropdownButton<String>(
                    value: _tipoMedia,
                    items: const [
                      DropdownMenuItem(value: 'video', child: Text('Vídeo')),
                      DropdownMenuItem(value: 'foto', child: Text('Foto')),
                    ],
                    onChanged: (v) =>
                        setState(() => _tipoMedia = v ?? _tipoMedia),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _urlController,
                      decoration: const InputDecoration(labelText: 'URL'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _guardandoMedia || userId == null
                    ? null
                    : () => _agregarMedia(userId),
                child: _guardandoMedia
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Añadir'),
              ),
              const SizedBox(height: 32),
              Text(
                'Marcar progreso de un alumno',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              FutureBuilder<List<AlumnoOption>>(
                future: _alumnosFuture,
                builder: (context, snapshot) {
                  final alumnos = snapshot.data ?? [];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: _alumnoSeleccionado,
                        decoration: const InputDecoration(labelText: 'Alumno'),
                        items: [
                          for (final a in alumnos)
                            DropdownMenuItem(
                              value: a.id,
                              child: Text(a.nombre),
                            ),
                        ],
                        onChanged: (v) =>
                            setState(() => _alumnoSeleccionado = v),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _estadoSeleccionado,
                        decoration: const InputDecoration(labelText: 'Estado'),
                        items: const [
                          DropdownMenuItem(
                            value: 'bloqueada',
                            child: Text('Bloqueada'),
                          ),
                          DropdownMenuItem(
                            value: 'en_proceso',
                            child: Text('En proceso'),
                          ),
                          DropdownMenuItem(
                            value: 'conseguida',
                            child: Text('Conseguida'),
                          ),
                        ],
                        onChanged: (v) => setState(
                          () => _estadoSeleccionado = v ?? _estadoSeleccionado,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _guardandoProgreso ? null : _guardarProgreso,
                        child: _guardandoProgreso
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Guardar progreso'),
                      ),
                    ],
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _etiquetaEstado(String estado) => switch (estado) {
    'bloqueada' => 'Bloqueada',
    'en_proceso' => 'En proceso',
    'conseguida' => 'Conseguida',
    _ => estado,
  };
}
