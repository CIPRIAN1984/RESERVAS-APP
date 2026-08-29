import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../core/models/profile.dart';

class EquipoRepository {
  EquipoRepository(this._client);

  final sb.SupabaseClient _client;

  Future<List<Profile>> listMiembros(String academiaId) async {
    final rows = await _client
        .from('profiles')
        .select()
        .eq('academia_id', academiaId)
        .order('nombre');

    final miembros = (rows as List)
        .map((row) => Profile.fromJson(row as Map<String, dynamic>))
        .toList();

    const ordenRol = {'dueño': 0, 'profesor': 1, 'alumno': 2};
    miembros.sort((a, b) {
      final porRol = (ordenRol[a.rol] ?? 3).compareTo(ordenRol[b.rol] ?? 3);
      if (porRol != 0) return porRol;
      return a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase());
    });
    return miembros;
  }

  Future<void> cambiarRol({
    required String miembroId,
    required String nuevoRol,
  }) async {
    await _client.rpc(
      'cambiar_rol_miembro',
      params: {'p_miembro_id': miembroId, 'p_nuevo_rol': nuevoRol},
    );
  }

  /// Reconoce una cuota cobrada en mano. El servidor comprueba que quien
  /// llama es el Dueño y que alumno y tarifa son de su academia.
  Future<void> activarCuotaEfectivo({
    required String alumnoId,
    required String tarifaId,
    required DateTime hasta,
  }) async {
    await _client.rpc(
      'activar_cuota_efectivo',
      params: {
        'p_alumno_id': alumnoId,
        'p_tarifa_id': tarifaId,
        'p_fecha_fin': hasta.toUtc().toIso8601String(),
      },
    );
  }

  /// Deja probar 1 día sin cobrar todavía. Caduca sola: no hace falta
  /// retirarla a mano si el alumno no sigue.
  Future<void> iniciarPrueba({
    required String alumnoId,
    required String tarifaId,
  }) async {
    await _client.rpc(
      'activar_cuota_efectivo',
      params: {
        'p_alumno_id': alumnoId,
        'p_tarifa_id': tarifaId,
        'p_prueba': true,
      },
    );
  }

  Future<void> retirarCuotaEfectivo(String suscripcionId) async {
    await _client.rpc(
      'desactivar_cuota_efectivo',
      params: {'p_suscripcion_id': suscripcionId},
    );
  }

  /// Congela una cuota activa. Sin [hasta] queda pausada hasta que se
  /// reanude a mano; con fecha, se reanuda ella sola.
  Future<void> pausarCuota({
    required String suscripcionId,
    DateTime? hasta,
  }) async {
    await _client.rpc(
      'pausar_cuota_efectivo',
      params: {
        'p_suscripcion_id': suscripcionId,
        'p_fecha_fin': hasta?.toUtc().toIso8601String(),
      },
    );
  }

  Future<void> reanudarCuota(String suscripcionId) async {
    await _client.rpc(
      'reanudar_cuota_efectivo',
      params: {'p_suscripcion_id': suscripcionId},
    );
  }

  /// Cuotas en curso de la academia (al día, en prueba o pausadas), por
  /// alumno, para saber de un vistazo sin pedir una consulta por cada fila
  /// de la lista.
  Future<
    Map<String, ({String id, String tarifa, bool efectivo, String estado})>
  >
  cuotasActivas(String academiaId) async {
    final rows =
        await _client
                .from('suscripciones')
                .select(
                  'id, alumno_id, proveedor_pago, estado, tarifa:tarifas(nombre)',
                )
                .eq('academia_id', academiaId)
                .inFilter('estado', ['activa', 'prueba', 'pausada'])
                .eq('payment_status', 'active')
            as List;

    return {
      for (final row in rows.cast<Map<String, dynamic>>())
        row['alumno_id'] as String: (
          id: row['id'] as String,
          tarifa:
              (row['tarifa'] as Map<String, dynamic>?)?['nombre'] as String? ??
              'Cuota',
          efectivo: row['proveedor_pago'] == 'efectivo',
          estado: row['estado'] as String,
        ),
    };
  }
}
