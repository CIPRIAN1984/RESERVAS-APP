import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/color_tokens.dart';
import '../application/tienda_providers.dart';
import '../data/pedido.dart';

class PedidosTab extends ConsumerWidget {
  const PedidosTab({super.key});

  Future<void> _cambiarEstado(WidgetRef ref, BuildContext context, Pedido pedido, String nuevoEstado) async {
    try {
      await ref.read(tiendaRepositoryProvider).actualizarEstadoPedido(pedido.id, nuevoEstado);
      ref.invalidate(pedidosStaffProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('No se ha podido actualizar el pedido.')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pedidosAsync = ref.watch(pedidosStaffProvider);

    return pedidosAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(
        child: Text('No se han podido cargar los pedidos.',
            style: TextStyle(color: Theme.of(context).colorScheme.error)),
      ),
      data: (pedidosOriginales) {
        if (pedidosOriginales.isEmpty) {
          return Center(
            child: Text(
              'Todavía no hay pedidos.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
          );
        }
        // Los checkouts abandonados (pendiente_pago) se hunden al final —
        // la cola accionable (reservado en adelante) es lo importante.
        final pedidos = [...pedidosOriginales]..sort((a, b) {
            final aPendiente = a.estado == 'pendiente_pago' ? 1 : 0;
            final bPendiente = b.estado == 'pendiente_pago' ? 1 : 0;
            return aPendiente.compareTo(bPendiente);
          });
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(pedidosStaffProvider),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: pedidos.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final pedido = pedidos[index];
              final pendienteDePago = pedido.estado == 'pendiente_pago';
              return Opacity(
                opacity: pendienteDePago ? 0.6 : 1,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(pedido.productoNombre ?? 'Producto', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 4),
                        Text(
                          '${pedido.alumnoNombre ?? 'Alumno'} · x${pedido.cantidad} · ${pedido.precioSnapshot.toStringAsFixed(2)} €',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat('d MMM, HH:mm', 'es_ES').format(pedido.createdAt.toLocal()),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Chip(label: Text(_etiquetaEstado(pedido.estado))),
                            Chip(label: Text(_etiquetaPago(pedido.paymentStatus))),
                            ..._accionesPara(pedido.estado).map(
                              (accion) => OutlinedButton(
                                onPressed: () => _cambiarEstado(ref, context, pedido, accion),
                                child: Text(_etiquetaEstado(accion)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  List<String> _accionesPara(String estado) => switch (estado) {
        'reservado' => const ['confirmado', 'cancelado'],
        'confirmado' => const ['entregado', 'cancelado'],
        _ => const [],
      };

  String _etiquetaEstado(String estado) => switch (estado) {
        'pendiente_pago' => 'Pago en proceso',
        'reservado' => 'Reservado',
        'confirmado' => 'Confirmado',
        'entregado' => 'Entregado',
        'cancelado' => 'Cancelado',
        _ => estado,
      };

  String _etiquetaPago(String paymentStatus) => switch (paymentStatus) {
        'pending' => 'Sin iniciar',
        'processing' => 'Procesando',
        'succeeded' => 'Pagado',
        'failed' => 'Pago fallido',
        'canceled' => 'Pago cancelado',
        'refunded' => 'Reembolsado',
        _ => paymentStatus,
      };
}
