import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import 'suscripcion.dart';
import 'tarifa.dart';

class TarifasRepository {
  TarifasRepository(this._client);

  final sb.SupabaseClient _client;

  Future<List<Tarifa>> listarTarifas({bool soloActivas = false}) async {
    var query = _client.from('tarifas').select();
    if (soloActivas) {
      query = query.eq('activo', true);
    }
    final rows = await query.order('precio') as List;
    return rows.map((r) => Tarifa.fromJson(r as Map<String, dynamic>)).toList();
  }

  Future<void> crearTarifa({
    required String academiaId,
    required String nombre,
    String? descripcion,
    required num precio,
    required String periodicidad,
    // null = ilimitada. Va aparte del precio a propósito: antes esto se
    // metía en el nombre («white 50 € 2 días por semana») y no había forma
    // de contar nada con ello.
    int? clasesIncluidas,
  }) async {
    await _client.from('tarifas').insert({
      'academia_id': academiaId,
      'nombre': nombre,
      'descripcion': descripcion,
      'precio': precio,
      'periodicidad': periodicidad,
      'clases_incluidas': clasesIncluidas,
    });
  }

  /// Cambiar una tarifa que ya existe.
  ///
  /// No toca `activo`: eso se hace desde el interruptor de la lista, y
  /// mezclarlo aquí haría que guardar cambios pudiera reactivar sin querer
  /// una tarifa que se había retirado.
  Future<void> actualizarTarifa({
    required String tarifaId,
    required String nombre,
    String? descripcion,
    required num precio,
    required String periodicidad,
    int? clasesIncluidas,
  }) async {
    await _client
        .from('tarifas')
        .update({
          'nombre': nombre,
          'descripcion': descripcion,
          'precio': precio,
          'periodicidad': periodicidad,
          'clases_incluidas': clasesIncluidas,
        })
        .eq('id', tarifaId);
  }

  Future<void> alternarActivo(String tarifaId, bool activo) async {
    await _client.from('tarifas').update({'activo': activo}).eq('id', tarifaId);
  }

  Future<Suscripcion?> suscripcionActiva(String alumnoId) async {
    final row = await _client
        .from('suscripciones')
        .select('*, tarifa:tarifas(nombre, precio, periodicidad)')
        .eq('alumno_id', alumnoId)
        .inFilter('estado', ['activa', 'pendiente_pago'])
        .maybeSingle();
    if (row == null) return null;
    return Suscripcion.fromRow(row);
  }

  Future<({String clientSecret, String stripeAccountId})> iniciarSuscripcion(
    String tarifaId,
  ) async {
    final res = await _client.functions.invoke(
      'stripe-create-tarifa-subscription',
      body: {'tarifa_id': tarifaId},
    );
    final data = res.data as Map<String, dynamic>;
    if (data['error'] != null) throw Exception(data['error'] as String);
    return (
      clientSecret: data['client_secret'] as String,
      stripeAccountId: data['stripe_account_id'] as String,
    );
  }

  Future<void> cancelarSuscripcion(String suscripcionId) async {
    final res = await _client.functions.invoke(
      'stripe-cancel-tarifa-subscription',
      body: {'suscripcion_id': suscripcionId},
    );
    final data = res.data as Map<String, dynamic>;
    if (data['error'] != null) throw Exception(data['error'] as String);
  }
}
