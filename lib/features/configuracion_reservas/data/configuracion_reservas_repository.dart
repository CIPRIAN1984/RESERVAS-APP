import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import 'configuracion_reservas.dart';

class ConfiguracionReservasRepository {
  ConfiguracionReservasRepository(this._client);

  final sb.SupabaseClient _client;

  Future<ConfiguracionReservas> obtener(String academiaId) async {
    final row = await _client
        .from('academias')
        .select(
          'lista_espera_activa, cancelacion_limite_minutos, zona_horaria, '
          'exigir_cuota_para_reservar',
        )
        .eq('id', academiaId)
        .single();
    return ConfiguracionReservas.fromJson(row);
  }

  Future<void> actualizar({
    required String academiaId,
    required bool listaEsperaActiva,
    required int cancelacionLimiteMinutos,
    required String zonaHoraria,
    required bool exigirCuotaParaReservar,
  }) async {
    await _client
        .from('academias')
        .update({
          'lista_espera_activa': listaEsperaActiva,
          'cancelacion_limite_minutos': cancelacionLimiteMinutos,
          'zona_horaria': zonaHoraria,
          'exigir_cuota_para_reservar': exigirCuotaParaReservar,
        })
        .eq('id', academiaId);
  }
}
