import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/color_tokens.dart';
import '../../../core/auth/auth_state.dart';
import '../../../shared/widgets/async_value_view.dart';
import '../application/novedades_providers.dart';
import '../data/novedad.dart';
import 'crear_novedad_screen.dart';

class NovedadesScreen extends ConsumerWidget {
  const NovedadesScreen({super.key});

  Future<void> _alternarFijado(
    WidgetRef ref,
    BuildContext context,
    Novedad novedad,
  ) async {
    try {
      await ref
          .read(novedadesRepositoryProvider)
          .alternarFijado(novedad.id, !novedad.fijado);
      ref.invalidate(novedadesProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se ha podido actualizar.')),
        );
      }
    }
  }

  Future<void> _eliminar(
    WidgetRef ref,
    BuildContext context,
    Novedad novedad,
  ) async {
    try {
      await ref.read(novedadesRepositoryProvider).eliminar(novedad.id);
      ref.invalidate(novedadesProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se ha podido eliminar.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider).value;
    final userId = ref.watch(currentUserIdProvider);
    final puedePublicar =
        profile != null &&
        (profile.isProfesor || profile.isDueno || profile.isAdministrador);
    final novedadesAsync = ref.watch(novedadesProvider);

    return Scaffold(
      floatingActionButton: (puedePublicar && profile.academiaId != null)
          ? FloatingActionButton.extended(
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => CrearNovedadScreen(
                      academiaId: profile.academiaId!,
                      autorId: userId!,
                    ),
                  ),
                );
                ref.invalidate(novedadesProvider);
              },
              icon: const Icon(Icons.add),
              label: const Text('Publicar'),
            )
          : null,
      body: AsyncListView<Novedad>(
        asyncValue: novedadesAsync,
        onRefresh: () async => ref.invalidate(novedadesProvider),
        emptyIcon: Icons.campaign_outlined,
        emptyMessage: 'Todavía no hay novedades.',
        itemBuilder: (context, novedad) => _NovedadCard(
          novedad: novedad,
          puedeGestionar: puedePublicar,
          onAlternarFijado: () => _alternarFijado(ref, context, novedad),
          onEliminar: () => _eliminar(ref, context, novedad),
        ),
      ),
    );
  }
}

class _NovedadCard extends StatelessWidget {
  const _NovedadCard({
    required this.novedad,
    required this.puedeGestionar,
    required this.onAlternarFijado,
    required this.onEliminar,
  });

  final Novedad novedad;
  final bool puedeGestionar;
  final VoidCallback onAlternarFijado;
  final VoidCallback onEliminar;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: novedad.fijado
          ? AppColors.accentPrimary.withValues(alpha: 0.10)
          : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (novedad.fijado) ...[
                  const Icon(
                    Icons.push_pin,
                    size: 16,
                    color: AppColors.accentPrimary,
                  ),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: Text(
                    novedad.titulo,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (puedeGestionar)
                  PopupMenuButton<String>(
                    icon: const Icon(
                      Icons.more_vert,
                      color: AppColors.textSecondary,
                    ),
                    onSelected: (value) {
                      if (value == 'fijar') onAlternarFijado();
                      if (value == 'eliminar') onEliminar();
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'fijar',
                        child: Text(novedad.fijado ? 'Desfijar' : 'Fijar'),
                      ),
                      const PopupMenuItem(
                        value: 'eliminar',
                        child: Text('Eliminar'),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              novedad.contenido,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Text(
              '${novedad.autorNombre ?? 'Desconocido'} · ${DateFormat('d MMM, HH:mm', 'es_ES').format(novedad.createdAt.toLocal())}',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
