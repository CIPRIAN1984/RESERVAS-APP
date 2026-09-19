import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/pantalla.dart';
import '../../horario/presentation/horario_screen.dart';
import '../../tarifas/presentation/tarifas_screen.dart';

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
        // No confundir con el calendario de Hoy: aquí se fija la plantilla
        // que se repite sola cada semana («BJJ lunes 19:00»); el día a día
        // —crear una clase suelta, cancelar un día concreto— sigue en Hoy.
        TarjetaAcceso(
          icono: Icons.event_repeat_outlined,
          titulo: 'Horario semanal',
          descripcion:
              'Las clases fijas de cada semana: se generan solas, sin '
              'tener que volver a crearlas.',
          destino: const HorarioScreen(),
        ),
        const SizedBox(height: 12),
        TarjetaAcceso(
          icono: Icons.card_membership_outlined,
          titulo: 'Tarifas y planes',
          descripcion:
              'Cuotas que pueden contratar tus alumnos: precio, '
              'periodicidad y sesiones incluidas.',
          destino: const TarifasScreen(),
        ),
      ],
    );
  }
}
