import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import 'pedido.dart';
import 'prestamo.dart';
import 'producto.dart';

typedef AlumnoOption = ({String id, String nombre});

class TiendaRepository {
  TiendaRepository(this._client);

  final sb.SupabaseClient _client;

  Future<List<AlumnoOption>> listarAlumnos(String academiaId) async {
    final rows =
        await _client
                .from('profiles')
                .select('id, nombre, apellidos')
                .eq('academia_id', academiaId)
                .eq('rol', 'alumno')
                .order('nombre')
            as List;
    return rows.map((r) {
      final row = r as Map<String, dynamic>;
      final nombre = [
        row['nombre'],
        row['apellidos'],
      ].whereType<String>().join(' ');
      return (id: row['id'] as String, nombre: nombre);
    }).toList();
  }

  Future<List<Producto>> listarProductos({bool soloActivos = false}) async {
    var query = _client.from('productos').select();
    if (soloActivos) {
      query = query.eq('activo', true);
    }
    final rows = await query.order('nombre') as List;
    return rows
        .map((r) => Producto.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  Future<void> crearProducto({
    required String academiaId,
    required String nombre,
    String? descripcion,
    required num precio,
    required int stock,
  }) async {
    await _client.from('productos').insert({
      'academia_id': academiaId,
      'nombre': nombre,
      'descripcion': descripcion,
      'precio': precio,
      'stock': stock,
    });
  }

  Future<void> alternarActivo(String productoId, bool activo) async {
    await _client
        .from('productos')
        .update({'activo': activo})
        .eq('id', productoId);
  }

  /// Inserts the order (lands in `pendiente_pago`) and returns its id, used
  /// right afterwards to kick off the Stripe payment.
  Future<String> crearPedido({
    required String productoId,
    required String alumnoId,
    int cantidad = 1,
  }) async {
    final row = await _client
        .from('pedidos')
        .insert({
          'producto_id': productoId,
          'alumno_id': alumnoId,
          'cantidad': cantidad,
        })
        .select('id')
        .single();
    return row['id'] as String;
  }

  /// Calls `stripe-create-tienda-payment` to get a PaymentIntent client
  /// secret for the given (already-inserted, `pendiente_pago`) order.
  Future<({String clientSecret, String stripeAccountId})> iniciarPagoPedido(
    String pedidoId,
  ) async {
    final res = await _client.functions.invoke(
      'stripe-create-tienda-payment',
      body: {'pedido_id': pedidoId},
    );
    final data = res.data as Map<String, dynamic>;
    return (
      clientSecret: data['client_secret'] as String,
      stripeAccountId: data['stripe_account_id'] as String,
    );
  }

  Future<List<Pedido>> listarPedidos({
    required bool soloPropios,
    String? alumnoId,
  }) async {
    var query = _client
        .from('pedidos')
        .select('*, alumno:profiles(nombre), producto:productos(nombre)');
    if (soloPropios && alumnoId != null) {
      query = query.eq('alumno_id', alumnoId);
    }
    final rows = await query.order('created_at', ascending: false) as List;
    return rows.map((r) => Pedido.fromRow(r as Map<String, dynamic>)).toList();
  }

  Future<void> actualizarEstadoPedido(String pedidoId, String estado) async {
    await _client.from('pedidos').update({'estado': estado}).eq('id', pedidoId);
  }

  Future<List<Prestamo>> listarPrestamos() async {
    final rows =
        await _client
                .from('prestamos')
                .select(
                  '*, alumno:profiles!prestamos_alumno_id_fkey(nombre), producto:productos(nombre)',
                )
                .order('fecha_prestamo', ascending: false)
            as List;
    return rows
        .map((r) => Prestamo.fromRow(r as Map<String, dynamic>))
        .toList();
  }

  Future<void> crearPrestamo({
    required String alumnoId,
    String? productoId,
    String? descripcion,
    required String gestionadoPor,
  }) async {
    await _client.from('prestamos').insert({
      'alumno_id': alumnoId,
      'producto_id': productoId,
      'descripcion': descripcion,
      'gestionado_por': gestionadoPor,
    });
  }

  Future<void> marcarDevuelto(String prestamoId) async {
    await _client
        .from('prestamos')
        .update({'fecha_devolucion': DateTime.now().toUtc().toIso8601String()})
        .eq('id', prestamoId);
  }
}
