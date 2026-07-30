import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_stripe/flutter_stripe.dart' hide Card;

import '../../../app/theme/color_tokens.dart';
import '../../../core/auth/auth_state.dart';
import '../../../core/utils/error_messages.dart';
import '../../../shared/widgets/pantalla.dart';
import '../application/tienda_providers.dart';
import '../data/producto.dart';
import 'crear_producto_screen.dart';

class CatalogoTab extends ConsumerStatefulWidget {
  const CatalogoTab({
    required this.puedeGestionar,
    required this.academiaId,
    this.alumnoId,
    super.key,
  });

  final bool puedeGestionar;
  final String academiaId;
  final String? alumnoId;

  @override
  ConsumerState<CatalogoTab> createState() => _CatalogoTabState();
}

class _CatalogoTabState extends ConsumerState<CatalogoTab> {
  String? _procesandoProductoId;

  Future<void> _reservar(Producto producto) async {
    final alumnoId = widget.alumnoId;
    if (alumnoId == null) return;

    final academia = ref.read(currentAcademiaProvider).value;
    if (academia == null || !academia.stripeChargesEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Esta academia todavía no ha configurado los cobros.'),
        ),
      );
      return;
    }

    setState(() => _procesandoProductoId = producto.id);
    final repo = ref.read(tiendaRepositoryProvider);
    try {
      final pedidoId = await repo.crearPedido(
        productoId: producto.id,
        alumnoId: alumnoId,
      );
      final pago = await repo.iniciarPagoPedido(pedidoId);

      Stripe.stripeAccountId = pago.stripeAccountId;
      await Stripe.instance.applySettings();

      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: pago.clientSecret,
          merchantDisplayName: 'I+',
        ),
      );
      await Stripe.instance.presentPaymentSheet();

      ref.invalidate(misPedidosProvider(alumnoId));
      ref.invalidate(productosProvider(true));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Pago realizado: ${producto.nombre}')),
        );
      }
    } on StripeException catch (e) {
      if (e.error.code == FailureCode.Canceled) return;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('El pago no se ha podido completar.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              mensajeErrorAmigable(e, generico: 'No se ha podido reservar.'),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _procesandoProductoId = null);
    }
  }

  Future<void> _alternarActivo(Producto producto) async {
    await ref
        .read(tiendaRepositoryProvider)
        .alternarActivo(producto.id, !producto.activo);
    ref.invalidate(productosProvider(false));
  }

  @override
  Widget build(BuildContext context) {
    final productosAsync = ref.watch(productosProvider(!widget.puedeGestionar));

    return Scaffold(
      floatingActionButton: widget.puedeGestionar
          ? FloatingActionButton.extended(
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        CrearProductoScreen(academiaId: widget.academiaId),
                  ),
                );
                ref.invalidate(productosProvider(!widget.puedeGestionar));
              },
              icon: const Icon(Icons.add),
              label: const Text('Producto'),
            )
          : null,
      body: productosAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(
          child: Text(
            'No se ha podido cargar el catálogo.',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
        data: (productos) {
          if (productos.isEmpty) {
            return Center(
              child: Text(
                'Todavía no hay productos en el catálogo.',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppColors.subtle),
              ),
            );
          }
          return ListView.separated(
            // Quien gestiona tiene el botón de añadir producto flotando
            // encima: hay que dejarle sitio.
            padding: EdgeInsets.fromLTRB(
              16,
              16,
              16,
              widget.puedeGestionar ? espacioBotonesFlotantes : 16,
            ),
            itemCount: productos.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final producto = productos[index];
              final procesando = _procesandoProductoId == producto.id;
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              producto.nombre,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            if (producto.descripcion != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                producto.descripcion!,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: AppColors.subtle),
                              ),
                            ],
                            const SizedBox(height: 8),
                            Text(
                              '${producto.precio.toStringAsFixed(2)} € · Stock: ${producto.stock}',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: AppColors.ink),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      if (widget.puedeGestionar)
                        Switch(
                          value: producto.activo,
                          onChanged: (_) => _alternarActivo(producto),
                        )
                      else if (procesando)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        ElevatedButton(
                          onPressed: producto.stock > 0
                              ? () => _reservar(producto)
                              : null,
                          child: Text(
                            producto.stock > 0 ? 'Reservar' : 'Agotado',
                          ),
                        ),
                    ],
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
