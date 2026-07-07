import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_state.dart';
import 'catalogo_tab.dart';
import 'mis_pedidos_tab.dart';
import 'pedidos_tab.dart';
import 'prestamos_tab.dart';

class TiendaScreen extends ConsumerWidget {
  const TiendaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider).value;
    final userId = ref.watch(currentUserIdProvider);

    if (profile == null || profile.academiaId == null || userId == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final puedeGestionar =
        profile.isProfesor || profile.isDueno || profile.isAdministrador;
    final academiaId = profile.academiaId!;

    final tabs = puedeGestionar
        ? const [
            Tab(text: 'Catálogo'),
            Tab(text: 'Pedidos'),
            Tab(text: 'Préstamos'),
          ]
        : const [Tab(text: 'Catálogo'), Tab(text: 'Mis pedidos')];

    final vistas = puedeGestionar
        ? [
            CatalogoTab(puedeGestionar: true, academiaId: academiaId),
            const PedidosTab(),
            PrestamosTab(academiaId: academiaId, gestionadoPor: userId),
          ]
        : [
            CatalogoTab(
              puedeGestionar: false,
              academiaId: academiaId,
              alumnoId: userId,
            ),
            MisPedidosTab(alumnoId: userId),
          ];

    return DefaultTabController(
      length: tabs.length,
      child: Column(
        children: [
          TabBar(tabs: tabs),
          Expanded(child: TabBarView(children: vistas)),
        ],
      ),
    );
  }
}
