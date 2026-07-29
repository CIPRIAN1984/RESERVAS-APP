import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/color_tokens.dart';
import '../../../shared/widgets/pantalla.dart';
import '../../calendario/presentation/calendario_screen.dart';
import '../../tarifas/presentation/tarifas_screen.dart';
import '../../tienda/presentation/tienda_screen.dart';

/// Panel de gestión diaria de la academia, con las dos pestañas de MAAT:
/// **Horario** (programar clases) y **Productos** (planes y material).
class HerramientasScreen extends ConsumerStatefulWidget {
  const HerramientasScreen({super.key});

  @override
  ConsumerState<HerramientasScreen> createState() => _HerramientasScreenState();
}

class _HerramientasScreenState extends ConsumerState<HerramientasScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Text(
            'Herramientas',
            style: Theme.of(context).textTheme.displayLarge,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: PestanasPildora(
            valor: _tab,
            etiquetas: const ['Horario', 'Productos'],
            onCambio: (i) => setState(() => _tab = i),
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: _tab == 0 ? const CalendarioScreen() : const _Productos(),
        ),
      ],
    );
  }
}

/// Los dos catálogos que gestiona la academia. Se dejan como accesos y no
/// como pestañas anidadas: meter pestañas dentro de pestañas se vuelve
/// confuso enseguida.
class _Productos extends StatelessWidget {
  const _Productos();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: [
        _TarjetaAcceso(
          icono: Icons.card_membership_outlined,
          titulo: 'Tarifas y planes',
          descripcion:
              'Cuotas que pueden contratar tus alumnos: precio, '
              'periodicidad y sesiones incluidas.',
          destino: const TarifasScreen(),
        ),
        const SizedBox(height: 12),
        _TarjetaAcceso(
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

class _TarjetaAcceso extends StatelessWidget {
  const _TarjetaAcceso({
    required this.icono,
    required this.titulo,
    required this.descripcion,
    required this.destino,
  });

  final IconData icono;
  final String titulo;
  final String descripcion;
  final Widget destino;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => Scaffold(
              appBar: AppBar(title: Text(titulo)),
              body: SafeArea(child: destino),
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Icon(icono, size: 26),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      descripcion,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: AppColors.subtle),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: AppColors.disabled,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
