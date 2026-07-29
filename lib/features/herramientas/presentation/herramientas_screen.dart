import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/pantalla.dart';
import '../../tarifas/presentation/tarifas_screen.dart';
import '../../tienda/presentation/tienda_screen.dart';

/// Lo que la academia administra y no es el día a día: catálogos y ajustes.
///
/// Antes tenía una pestaña «Horario» que embebía el calendario entero. Era
/// exactamente la misma pantalla que **Hoy**, saludo del atleta incluido: dos
/// sitios distintos para lo mismo, y ninguno de los dos claramente el bueno.
/// El horario vive en Hoy y aquí quedan las herramientas.
class HerramientasScreen extends ConsumerWidget {
  const HerramientasScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: [
        TarjetaAcceso(
          icono: Icons.card_membership_outlined,
          titulo: 'Tarifas y planes',
          descripcion:
              'Cuotas que pueden contratar tus alumnos: precio, '
              'periodicidad y sesiones incluidas.',
          destino: const TarifasScreen(),
        ),
        const SizedBox(height: 12),
        TarjetaAcceso(
          icono: Icons.storefront_outlined,
          titulo: 'Tienda y material',
          descripcion:
              'Catálogo de productos, pedidos de los alumnos y préstamos '
              'de material.',
          destino: const TiendaScreen(),
        ),
      ],
    );
  }
}
