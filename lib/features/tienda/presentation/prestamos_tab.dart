import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/color_tokens.dart';
import '../../../shared/widgets/pantalla.dart';
import '../application/tienda_providers.dart';
import 'crear_prestamo_screen.dart';

class PrestamosTab extends ConsumerWidget {
  const PrestamosTab({
    required this.academiaId,
    required this.gestionadoPor,
    super.key,
  });

  final String academiaId;
  final String gestionadoPor;

  Future<void> _marcarDevuelto(
    WidgetRef ref,
    BuildContext context,
    String prestamoId,
  ) async {
    try {
      await ref.read(tiendaRepositoryProvider).marcarDevuelto(prestamoId);
      ref.invalidate(prestamosProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se ha podido registrar la devolución.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prestamosAsync = ref.watch(prestamosProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => CrearPrestamoScreen(
                academiaId: academiaId,
                gestionadoPor: gestionadoPor,
              ),
            ),
          );
          ref.invalidate(prestamosProvider);
        },
        icon: const Icon(Icons.add),
        label: const Text('Préstamo'),
      ),
      body: prestamosAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(
          child: Text(
            'No se han podido cargar los préstamos.',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
        data: (prestamos) {
          if (prestamos.isEmpty) {
            return Center(
              child: Text(
                'Todavía no hay préstamos registrados.',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppColors.subtle),
              ),
            );
          }
          return ListView.separated(
            // Debajo del botón flotante de registrar préstamo.
            padding: const EdgeInsets.fromLTRB(
              16,
              16,
              16,
              espacioBotonesFlotantes,
            ),
            itemCount: prestamos.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final prestamo = prestamos[index];
              return Card(
                child: ListTile(
                  title: Text(prestamo.itemDescripcion),
                  subtitle: Text(
                    '${prestamo.alumnoNombre ?? 'Alumno'} · Prestado el '
                    '${DateFormat('d MMM', 'es_ES').format(prestamo.fechaPrestamo.toLocal())}',
                  ),
                  trailing: prestamo.devuelto
                      ? const Chip(label: Text('Devuelto'))
                      : OutlinedButton(
                          onPressed: () =>
                              _marcarDevuelto(ref, context, prestamo.id),
                          child: const Text('Marcar devuelto'),
                        ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
