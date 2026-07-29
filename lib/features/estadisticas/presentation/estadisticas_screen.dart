import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/color_tokens.dart';
import '../../../core/auth/auth_state.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/pantalla.dart';
import '../application/estadisticas_providers.dart';
import '../data/ranking_entry.dart';

/// Ranking de asistencia del mes: podio con los tres primeros y lista
/// numerada con el resto, como en el prototipo I+.
class EstadisticasScreen extends ConsumerWidget {
  const EstadisticasScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rankingAsync = ref.watch(rankingMensualProvider);
    final userId = ref.watch(currentUserIdProvider);
    final mes = DateFormat.yMMMM('es_ES').format(DateTime.now());

    // El título vive fuera del `when`: antes, cuando no había ranking, el
    // estado vacío sustituía la pantalla entera y se llevaba por delante la
    // cabecera, así que no sabías ni en qué pantalla estabas.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TituloPantalla('Estadísticas', antetitulo: mes),
        Expanded(child: _contenido(context, rankingAsync, userId)),
      ],
    );
  }

  Widget _contenido(
    BuildContext context,
    AsyncValue<List<RankingEntry>> rankingAsync,
    String? userId,
  ) {
    return rankingAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => const EmptyState(
        icon: Icons.leaderboard_outlined,
        message: 'No se ha podido cargar el ranking.',
      ),
      data: (ranking) {
        if (ranking.isEmpty) {
          return const EmptyState(
            icon: Icons.leaderboard_outlined,
            message: 'Todavía no hay clases con asistencia este mes.',
          );
        }

        final podio = ranking.take(3).toList();
        final resto = ranking.skip(3).toList();

        return ListView(
          padding: const EdgeInsets.only(bottom: 28),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Text(
                podio.length >= 3 ? 'Top 3 del mes' : 'Ranking del mes',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            _Podio(podio: podio, userId: userId),
            if (resto.isNotEmpty) ...[
              const SizedBox(height: 28),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Text(
                  'Clasificación',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              for (var i = 0; i < resto.length; i++)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: _FilaRanking(
                    posicion: i + 4,
                    entry: resto[i],
                    esYo: resto[i].alumnoId == userId,
                  ),
                ),
            ],
          ],
        );
      },
    );
  }
}

/// Podio: el primero más alto y con corona. Los pedestales son de distinta
/// altura para que el orden se lea sin tener que mirar los números.
class _Podio extends StatelessWidget {
  const _Podio({required this.podio, required this.userId});

  final List<RankingEntry> podio;
  final String? userId;

  @override
  Widget build(BuildContext context) {
    // Orden visual: segundo, primero, tercero.
    final ordenVisual = <(int, RankingEntry)>[
      if (podio.length > 1) (2, podio[1]),
      (1, podio[0]),
      if (podio.length > 2) (3, podio[2]),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final (puesto, entry) in ordenVisual)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: _Pedestal(
                  puesto: puesto,
                  entry: entry,
                  esYo: entry.alumnoId == userId,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Pedestal extends StatelessWidget {
  const _Pedestal({
    required this.puesto,
    required this.entry,
    required this.esYo,
  });

  final int puesto;
  final RankingEntry entry;
  final bool esYo;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final primero = puesto == 1;
    // El más bajo tiene que seguir dando cabida a la cifra y a "clases".
    final alto = switch (puesto) {
      1 => 96.0,
      2 => 78.0,
      _ => 64.0,
    };

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (primero)
          const Icon(Icons.emoji_events, size: 26, color: Color(0xFFE9A800)),
        if (primero) const SizedBox(height: 6),
        _Avatar(entry: entry, radio: primero ? 32 : 26),
        const SizedBox(height: 8),
        Text(
          entry.nombre,
          style: t.titleSmall,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
        if (entry.cinturon != null)
          Text(
            entry.cinturon!.toUpperCase(),
            style: t.labelSmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        const SizedBox(height: 8),
        Container(
          height: alto,
          width: double.infinity,
          decoration: BoxDecoration(
            color: esYo ? AppColors.surfaceStrong : AppColors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
          ),
          alignment: Alignment.topCenter,
          padding: const EdgeInsets.only(top: 10),
          child: Column(
            children: [
              Text(
                '${entry.asistenciasCount}',
                style: t.headlineMedium?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Text('clases', style: t.labelSmall),
            ],
          ),
        ),
      ],
    );
  }
}

class _FilaRanking extends StatelessWidget {
  const _FilaRanking({
    required this.posicion,
    required this.entry,
    required this.esYo,
  });

  final int posicion;
  final RankingEntry entry;
  final bool esYo;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Card(
      color: esYo ? AppColors.surfaceStrong : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            SizedBox(
              width: 26,
              child: Text(
                '$posicion',
                textAlign: TextAlign.center,
                style: t.labelSmall?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            const SizedBox(width: 8),
            _Avatar(entry: entry, radio: 21),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.nombreCompleto,
                    style: t.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (entry.cinturon != null)
                    Text(entry.cinturon!.toUpperCase(), style: t.labelSmall),
                ],
              ),
            ),
            Text(
              '${entry.asistenciasCount}',
              style: t.titleMedium?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Foto del alumno con el punto de su cinturón, que es dato y no adorno.
class _Avatar extends StatelessWidget {
  const _Avatar({required this.entry, required this.radio});

  final RankingEntry entry;
  final double radio;

  @override
  Widget build(BuildContext context) {
    final iniciales = entry.nombre.isNotEmpty
        ? entry.nombre[0].toUpperCase()
        : '?';

    return SizedBox(
      width: radio * 2,
      height: radio * 2,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          CircleAvatar(
            radius: radio,
            backgroundColor: AppColors.surfaceStrong,
            backgroundImage: entry.fotoUrl != null
                ? CachedNetworkImageProvider(entry.fotoUrl!)
                : null,
            child: entry.fotoUrl == null
                ? Text(
                    iniciales,
                    style: TextStyle(
                      fontSize: radio * 0.8,
                      fontWeight: FontWeight.w700,
                      color: AppColors.subtle,
                    ),
                  )
                : null,
          ),
          Positioned(
            right: -1,
            bottom: -1,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                color: AppColors.ground,
                shape: BoxShape.circle,
              ),
              child: PuntoCinturon(entry.cinturon, tamano: radio * 0.52),
            ),
          ),
        ],
      ),
    );
  }
}
