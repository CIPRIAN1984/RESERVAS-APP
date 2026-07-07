import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/color_tokens.dart';
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
        child: Text('No se han podido cargar tus pedidos.',
            style: TextStyle(color: Theme.of(context).colorScheme.error)),
      ),
      data: (pedidos) {
        if (pedidos.isEmpty) {
          return Center(
            child: Text(
              'Todavía no has hecho ningún pedido.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
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
              return Card(
                child: ListTile(
                  title: Text(pedido.productoNombre ?? 'Producto'),
                  subtitle: Text(
                    'x${pedido.cantidad} · ${pedido.precioSnapshot.toStringAsFixed(2)} € · '
                    '${DateFormat('d MMM', 'es_ES').format(pedido.createdAt.toLocal())}',
                  ),
                  trailing: Chip(label: Text(_etiquetaEstado(pedido.estado))),
                ),
              );
            },
          ),
        );
      },
    );
  }

  String _etiquetaEstado(String estado) => switch (estado) {
        'pendiente_pago' => 'Pago en proceso',
        'reservado' => 'Reservado',
        'confirmado' => 'Confirmado',
        'entregado' => 'Entregado',
        'cancelado' => 'Cancelado',
        _ => estado,
      };
}
