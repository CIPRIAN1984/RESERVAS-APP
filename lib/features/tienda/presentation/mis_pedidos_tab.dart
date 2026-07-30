import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/color_tokens.dart';
import '../../../shared/widgets/pantalla.dart';
import '../application/tienda_providers.dart';

class MisPedidosTab extends ConsumerWidget {
  const MisPedidosTab({required this.alumnoId, super.key});

  final String alumnoId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pedidosAsync = ref.watch(misPedidosProvider(alumnoId));

    return pedidosAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(
        child: Text(
          'No se han podido cargar tus pedidos.',
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ),
      data: (pedidos) {
        if (pedidos.isEmpty) {
          return Center(
            child: Text(
              'Todavía no has hecho ningún pedido.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.subtle),
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(misPedidosProvider(alumnoId)),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: pedidos.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final pedido = pedidos[index];
              return TarjetaFila(
                titulo: pedido.productoNombre ?? 'Producto',
                detalle:
                    'x${pedido.cantidad} · ${pedido.precioSnapshot.toStringAsFixed(2)} € · '
                    '${DateFormat('d MMM', 'es_ES').format(pedido.createdAt.toLocal())}',
                estado: _pastilla(pedido.estado),
              );
            },
          ),
        );
      },
    );
  }

  /// El color aquí significa algo: entregado y confirmado en verde, cancelado
  /// en rojo, el pago a medias en ámbar.
  Widget _pastilla(String estado) => switch (estado) {
    'pendiente_pago' => const PastillaEstado.aviso('Pago en proceso'),
    'reservado' => const PastillaEstado.info('Reservado'),
    'confirmado' => const PastillaEstado.exito('Confirmado'),
    'entregado' => const PastillaEstado.exito('Entregado'),
    'cancelado' => const PastillaEstado.error('Cancelado'),
    _ => PastillaEstado(estado),
  };
}
