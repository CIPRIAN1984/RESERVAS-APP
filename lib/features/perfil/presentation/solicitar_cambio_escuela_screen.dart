import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/color_tokens.dart';
import '../application/cambio_escuela_providers.dart';
import '../data/solicitud_cambio_escuela.dart';

class SolicitarCambioEscuelaScreen extends ConsumerStatefulWidget {
  const SolicitarCambioEscuelaScreen({
    required this.alumnoId,
    required this.academiaActualId,
    super.key,
  });

  final String alumnoId;
  final String academiaActualId;

  @override
  ConsumerState<SolicitarCambioEscuelaScreen> createState() =>
      _SolicitarCambioEscuelaScreenState();
}

class _SolicitarCambioEscuelaScreenState
    extends ConsumerState<SolicitarCambioEscuelaScreen> {
  String? _academiaDestino;
  bool _enviando = false;
  String? _error;

  Future<void> _enviar() async {
    if (_academiaDestino == null) {
      setState(() => _error = 'Selecciona una academia.');
      return;
    }
    setState(() {
      _enviando = true;
      _error = null;
    });
    try {
      await ref
          .read(cambioEscuelaRepositoryProvider)
          .crearSolicitud(
            alumnoId: widget.alumnoId,
            academiaDestinoId: _academiaDestino!,
          );
      ref.invalidate(misSolicitudesCambioProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = 'No se ha podido enviar la solicitud.');
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final misSolicitudesAsync = ref.watch(misSolicitudesCambioProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Cambio de escuela')),
      body: SafeArea(
        child: misSolicitudesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, st) => Center(
            child: Text(
              'No se ha podido cargar tu solicitud.',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
          data: (solicitudes) {
            final pendiente = solicitudes
                .where((s) => s.estado == 'pendiente')
                .firstOrNull;
            if (pendiente != null) {
              return Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.hourglass_top_outlined,
                      size: 48,
                      color: AppColors.warningFg,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Tienes una solicitud pendiente para cambiarte a '
                      '${pendiente.academiaDestinoNombre}.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'El dueño de esa academia tiene que aceptarla.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.subtle,
                      ),
                    ),
                  ],
                ),
              );
            }
            return _buildFormulario(context, solicitudes);
          },
        ),
      ),
    );
  }

  Widget _buildFormulario(
    BuildContext context,
    List<MiSolicitudCambio> historial,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Solicita cambiarte a otra academia. El dueño de la academia destino '
            'tendrá que aceptar tu solicitud.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.subtle),
          ),
          const SizedBox(height: 24),
          FutureBuilder(
            future: ref
                .read(cambioEscuelaRepositoryProvider)
                .listarAcademiasAprobadas(),
            builder: (context, snapshot) {
              final academias = (snapshot.data ?? [])
                  .where((a) => a.id != widget.academiaActualId)
                  .toList();
              return DropdownButtonFormField<String>(
                initialValue: _academiaDestino,
                decoration: const InputDecoration(labelText: 'Nueva academia'),
                items: [
                  for (final a in academias)
                    DropdownMenuItem(value: a.id, child: Text(a.nombre)),
                ],
                onChanged: (v) => setState(() => _academiaDestino = v),
              );
            },
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _enviando ? null : _enviar,
            child: _enviando
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Enviar solicitud'),
          ),
          if (historial.isNotEmpty) ...[
            const SizedBox(height: 32),
            Text('Historial', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final s in historial)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(s.academiaDestinoNombre),
                trailing: Chip(label: Text(_etiqueta(s.estado))),
              ),
          ],
        ],
      ),
    );
  }

  String _etiqueta(String estado) => switch (estado) {
    'pendiente' => 'Pendiente',
    'aprobada' => 'Aprobada',
    'rechazada' => 'Rechazada',
    _ => estado,
  };
}
