import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/color_tokens.dart';
import '../../../core/auth/auth_state.dart';
import '../application/estadisticas_providers.dart';
import '../data/ranking_entry.dart';

class EstadisticasScreen extends ConsumerWidget {
  const EstadisticasScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rankingAsync = ref.watch(rankingMensualProvider);
    final userId = ref.watch(currentUserIdProvider);
    final mesLabel = DateFormat.yMMMM('es_ES').format(DateTime.now());

    return rankingAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(
        child: Text(
          'No se ha podido cargar el ranking.',
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ),
      data: (ranking) {
        if (ranking.isEmpty) {
          return Center(
            child: Text(
              'Todavía no hay alumnos en la academia.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
          );
        }
        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  mesLabel[0].toUpperCase() + mesLabel.substring(1),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
            SliverList.separated(
              itemCount: ranking.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final entry = ranking[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _RankingTile(
                    posicion: index + 1,
                    entry: entry,
                    esYo: entry.alumnoId == userId,
                  ),
                );
              },
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
          ],
        );
      },
    );
  }
}

class _RankingTile extends StatelessWidget {
  const _RankingTile({
    required this.posicion,
    required this.entry,
    required this.esYo,
  });

  final int posicion;
  final RankingEntry entry;
  final bool esYo;

  Color get _colorPosicion => switch (posicion) {
    1 => const Color(0xFFFFC947),
    2 => const Color(0xFFC7CBD1),
    3 => const Color(0xFFCE8946),
    _ => AppColors.surfaceElevatedHigh,
  };

  @override
  Widget build(BuildContext context) {
    final colorCinturon = entry.cinturon != null
        ? AppColors.beltColors[entry.cinturon!] ?? AppColors.textSecondary
        : AppColors.textSecondary;

    return Card(
      color: esYo ? AppColors.accentPrimary.withValues(alpha: 0.12) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            SizedBox(
              width: 32,
              child: Text(
                '$posicion',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: posicion <= 3
                      ? _colorPosicion
                      : AppColors.textSecondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),
            CircleAvatar(
              radius: 22,
              backgroundColor: colorCinturon.withValues(alpha: 0.4),
              child: CircleAvatar(
                radius: 19,
                backgroundColor: AppColors.surfaceElevated,
                backgroundImage: entry.fotoUrl != null
                    ? CachedNetworkImageProvider(entry.fotoUrl!)
                    : null,
                child: entry.fotoUrl == null
                    ? const Icon(Icons.person, color: AppColors.textSecondary)
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.nombreCompleto,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  if (entry.cinturon != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Cinturón ${entry.cinturon}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${entry.asistenciasCount}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.accentSecondary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'asistencias',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
