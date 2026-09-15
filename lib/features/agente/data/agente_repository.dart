import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import 'clave_agente.dart';

/// Las claves de solo lectura del agente personal del Dueño.
///
/// Todo pasa por funciones del servidor: las tablas `claves_agente` y
/// `consultas_agente` no se pueden leer ni escribir desde la app, ni siquiera
/// siendo Dueño. Así, si algún día se cuela un fallo en la app, lo peor que
/// puede hacer es llamar a estas cuatro funciones — que ya comprueban el rol
/// y la academia por su cuenta.
class AgenteRepository {
  AgenteRepository(this._client);

  final sb.SupabaseClient _client;

  Future<List<ClaveAgente>> listarClaves() async {
    final filas = await _client.rpc('listar_claves_agente') as List;
    return filas
        .cast<Map<String, dynamic>>()
        .map(ClaveAgente.fromJson)
        .toList();
  }

  /// Crea una clave y devuelve su texto **en claro, la única vez que se ve**.
  /// Si el Dueño no la copia ahora, no hay forma de recuperarla: se anula y
  /// se hace otra.
  Future<String> crearClave({
    required String nombre,
    required bool incluyeContacto,
  }) async {
    final clave = await _client.rpc(
      'crear_clave_agente',
      params: {'p_nombre': nombre, 'p_incluye_contacto': incluyeContacto},
    );
    return clave as String;
  }

  Future<void> revocar(String claveId) async {
    await _client.rpc('revocar_clave_agente', params: {'p_clave_id': claveId});
  }

  Future<List<ConsultaAgente>> ultimasConsultas({int limite = 20}) async {
    final filas =
        await _client.rpc(
              'listar_consultas_agente',
              params: {'p_limite': limite},
            )
            as List;
    return filas
        .cast<Map<String, dynamic>>()
        .map(ConsultaAgente.fromJson)
        .toList();
  }
}
