import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/color_tokens.dart';
import '../../../core/auth/auth_state.dart';
import '../../../core/models/academia.dart';

final _academiasTodasProvider = FutureProvider.autoDispose<List<Academia>>((
  ref,
) {
  return ref.watch(authRepositoryProvider).listAcademiasTodas();
});

class AdminAcademiasScreen extends ConsumerWidget {
  const AdminAcademiasScreen({super.key});

  Future<void> _resolver(
    WidgetRef ref,
    BuildContext context, {
    required Academia academia,
    required bool aprobar,
  }) async {
    final repo = ref.read(authRepositoryProvider);
    try {
      if (aprobar) {
        await repo.aprobarAcademia(academia.id);
      } else {
        await repo.rechazarAcademia(academia.id);
      }
      ref.invalidate(_academiasTodasProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              aprobar
                  ? '${academia.nombre} aprobada.'
                  : '${academia.nombre} rechazada.',
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se ha podido completar la acción.')),
        );
      }
    }
  }

  String _etiquetaEstado(String estado) => switch (estado) {
    'pending' => 'Pendiente',
    'approved' => 'Aprobada',
    'rejected' => 'Rechazada',
    _ => estado,
  };

  Color _colorEstado(String estado) => switch (estado) {
    'pending' => AppColors.warning,
    'approved' => AppColors.success,
    'rejected' => AppColors.danger,
    _ => AppColors.textSecondary,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final academiasAsync = ref.watch(_academiasTodasProvider);

    return academiasAsync.when(
      data: (academias) {
        if (academias.isEmpty) {
          return Center(
            child: Text(
              'Todavía no hay academias registradas.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(_academiasTodasProvider),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: academias.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final academia = academias[index];
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              academia.nombre,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          Chip(
                            label: Text(_etiquetaEstado(academia.estado)),
                            backgroundColor: _colorEstado(
                              academia.estado,
                            ).withValues(alpha: 0.16),
                            labelStyle: TextStyle(
                              color: _colorEstado(academia.estado),
                            ),
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                      if (academia.direccion?.isNotEmpty ?? false) ...[
                        const SizedBox(height: 4),
                        Text(
                          academia.direccion!,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                      if (academia.emailContacto?.isNotEmpty ?? false) ...[
                        const SizedBox(height: 4),
                        Text(
                          academia.emailContacto!,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                      if (academia.estado == 'pending') ...[
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => _resolver(
                                  ref,
                                  context,
                                  academia: academia,
                                  aprobar: false,
                                ),
                                child: const Text('Rechazar'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () => _resolver(
                                  ref,
                                  context,
                                  academia: academia,
                                  aprobar: true,
                                ),
                                child: const Text('Aprobar'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(
        child: Text(
          'No se pudieron cargar las academias.',
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ),
    );
  }
}
