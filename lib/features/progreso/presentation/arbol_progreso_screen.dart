import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/color_tokens.dart';
import '../../../core/auth/auth_state.dart';
import '../application/progreso_providers.dart';
import '../data/tecnica.dart';
import 'cinturon_section.dart';
import 'crear_tecnica_screen.dart';
import 'tecnica_detalle_screen.dart';

class ArbolProgresoScreen extends ConsumerWidget {
  const ArbolProgresoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider).value;
    final esAlumno = profile?.isAlumno ?? false;
    final puedeGestionar =
        profile != null &&
        (profile.isProfesor || profile.isDueno || profile.isAdministrador);

    final tecnicasAsync = ref.watch(tecnicasProvider);
    final progreso = esAlumno ? ref.watch(miProgresoProvider).value : null;

    return Scaffold(
      floatingActionButton: (puedeGestionar && profile.academiaId != null)
          ? FloatingActionButton.extended(
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        CrearTecnicaScreen(academiaId: profile.academiaId!),
                  ),
                );
                ref.invalidate(tecnicasProvider);
              },
              icon: const Icon(Icons.add),
              label: const Text('Técnica'),
            )
          : null,
      body: tecnicasAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(
          child: Text(
            'No se han podido cargar las técnicas.',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
        data: (tecnicas) {
          if (tecnicas.isEmpty) {
            return Center(
              child: Text(
                'Todavía no hay técnicas en el árbol de progreso.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            );
          }
          final agrupadas = <String, List<Tecnica>>{};
          for (final t in tecnicas) {
            agrupadas.putIfAbsent(t.cinturon, () => []).add(t);
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final cinturon in ordenCinturones)
                if (agrupadas[cinturon]?.isNotEmpty ?? false)
                  CinturonSection(
                    cinturon: cinturon,
                    tecnicas: agrupadas[cinturon]!,
                    progreso: progreso,
                    onTapTecnica: (tecnica) async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              TecnicaDetalleScreen(tecnica: tecnica),
                        ),
                      );
                      ref.invalidate(miProgresoProvider);
                    },
                  ),
            ],
          );
        },
      ),
    );
  }
}
