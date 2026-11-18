import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import 'pago_tarjeta.dart';

class PagosRepository {
  PagosRepository(this._client);

  final sb.SupabaseClient _client;

  /// Calls the `stripe-connect-onboarding` edge function and returns the
  /// Stripe-hosted onboarding URL to open externally. Throws
  /// `sb.FunctionException` on a non-2xx response (e.g. not a Dueño).
  Future<String> obtenerUrlOnboarding() async {
    final res = await _client.functions.invoke('stripe-connect-onboarding');
    final data = res.data as Map<String, dynamic>;
    return data['url'] as String;
  }

  /// Calls `stripe-connect-status` to refresh onboarding status immediately
  /// (rather than waiting for the webhook), returning the updated status.
  Future<({String estado, bool cobrosHabilitados})> refrescarEstado() async {
    final res = await _client.functions.invoke('stripe-connect-status');
    final data = res.data as Map<String, dynamic>;
    return (
      estado: data['stripe_onboarding_status'] as String,
      cobrosHabilitados: data['stripe_charges_enabled'] as bool,
    );
  }

  /// Prepara el pago de una cuota con tarjeta y devuelve la dirección de la
  /// página de pago de Stripe. El importe lo fija el servidor. Si es para un
  /// hijo, se manda su [alumnoId]. Un error del servidor (por ejemplo «ya
  /// tiene una renovación pendiente») sale como [MensajePago].
  Future<({String url, String pagoId})> iniciarPagoCuota({
    required String tarifaId,
    String? alumnoId,
  }) async {
    try {
      final res = await _client.functions.invoke(
        'stripe-checkout-tarifa',
        body: {'tarifa_id': tarifaId, 'alumno_id': ?alumnoId},
      );
      final data = res.data as Map<String, dynamic>;
      return (url: data['url'] as String, pagoId: data['pago_id'] as String);
    } on sb.FunctionException catch (e) {
      final detalle = e.details;
      if (detalle is Map && detalle['error'] is String) {
        throw MensajePago(detalle['error'] as String);
      }
      rethrow;
    }
  }

  /// Pide al servidor que consulte a Stripe el estado de un pago y lo
  /// devuelve. No activa nada por sí mismo: lo hace el servidor si Stripe
  /// confirma el cobro.
  Future<String> comprobarPago(String pagoId) async {
    final res = await _client.functions.invoke(
      'stripe-comprobar-pago',
      body: {'pago_id': pagoId},
    );
    return (res.data as Map<String, dynamic>)['estado'] as String;
  }

  Future<PagoTarjeta?> obtenerPago(String pagoId) async {
    final row = await _client
        .from('pagos_stripe')
        .select(
          'id, estado, importe_esperado, importe_pagado, error, created_at',
        )
        .eq('id', pagoId)
        .maybeSingle();
    return row == null ? null : PagoTarjeta.fromRow(row);
  }

  /// Pagos con tarjeta que la academia tiene que mirar: cobrados sin cuota
  /// activada, fallidos, abandonados o con un intento rechazado. Solo los ve
  /// el Dueño.
  Future<List<PagoTarjeta>> pagosConProblema() async {
    final rows =
        await _client
                .from('pagos_stripe')
                .select(
                  'id, estado, importe_esperado, importe_pagado, error, created_at, '
                  'alumno:profiles!pagos_stripe_alumno_id_fkey(nombre, apellidos)',
                )
                .or(
                  'estado.in.(revisar,fallido,expirado),and(estado.eq.creado,error.not.is.null)',
                )
                .order('created_at', ascending: false)
                .limit(50)
            as List;
    return rows.cast<Map<String, dynamic>>().map(PagoTarjeta.fromRow).toList();
  }
}

/// Un mensaje del servidor que se puede enseñar tal cual a la persona.
class MensajePago implements Exception {
  const MensajePago(this.mensaje);

  final String mensaje;

  @override
  String toString() => mensaje;
}
