import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/color_tokens.dart';
import '../application/cambio_escuela_providers.dart';

class SolicitudesCambioEscuelaScreen extends ConsumerWidget {
  const SolicitudesCambioEscuelaScreen({super.key});

  Future<void> _resolver(
    WidgetRef ref,
    BuildContext context,
    String solicitudId,
    bool aprobar,
  ) async {
    try {
      await ref
          .read(cambioEscuelaRepositoryProvider)
          .resolver(solicitudId: solicitudId, aprobar: aprobar);
      ref.invalidate(solicitudesCambioPendientesProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              aprobar ? 'Solicitud aprobada.' : 'Solicitud rechazada.',
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se ha podido resolver la solicitud.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final solicitudesAsync = ref.watch(solicitudesCambioPendientesProvider);

    return solicitudesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(
        child: Text(
          'No se han podido cargar las solicitudes.',
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ),
      data: (solicitudes) {
        if (solicitudes.isEmpty) {
          return Center(
            child: Text(
              'No hay solicitudes de cambio de escuela pendientes.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.subtle),
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () async =>
              ref.invalidate(solicitudesCambioPendientesProvider),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: solicitudes.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final solicitud = solicitudes[index];
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        solicitud.alumnoNombre,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Desde ${solicitud.academiaOrigenNombre} · '
                        '${DateFormat('d MMM', 'es_ES').format(solicitud.createdAt.toLocal())}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.subtle,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () =>
                                  _resolver(ref, context, solicitud.id, false),
                              child: const Text('Rechazar'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () =>
                                  _resolver(ref, context, solicitud.id, true),
                              child: const Text('Aprobar'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
