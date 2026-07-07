import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_client.dart';
import '../data/pedido.dart';
import '../data/prestamo.dart';
import '../data/producto.dart';
import '../data/tienda_repository.dart';

final tiendaRepositoryProvider = Provider<TiendaRepository>((ref) {
  return TiendaRepository(AppSupabase.client);
});

final productosProvider = FutureProvider.autoDispose.family<List<Producto>, bool>((ref, soloActivos) {
  return ref.watch(tiendaRepositoryProvider).listarProductos(soloActivos: soloActivos);
});

final pedidosStaffProvider = FutureProvider.autoDispose<List<Pedido>>((ref) {
  return ref.watch(tiendaRepositoryProvider).listarPedidos(soloPropios: false);
});

final misPedidosProvider = FutureProvider.autoDispose.family<List<Pedido>, String>((ref, alumnoId) {
  return ref.watch(tiendaRepositoryProvider).listarPedidos(soloPropios: true, alumnoId: alumnoId);
});

final prestamosProvider = FutureProvider.autoDispose<List<Prestamo>>((ref) {
  return ref.watch(tiendaRepositoryProvider).listarPrestamos();
});
