import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import 'ranking_entry.dart';

class EstadisticasRepository {
  EstadisticasRepository(this._client);

  final sb.SupabaseClient _client;

  /// [desde]/[hasta] nulos piden el ranking desde siempre, sin límite por
  /// ese lado. El mes/año/siempre que ve Cipri en la pantalla se decide en
  /// Flutter; esta RPC solo filtra el rango que le llega.
  Future<List<RankingEntry>> rankingPeriodo({
    DateTime? desde,
    DateTime? hasta,
  }) async {
    final rows =
        await _client.rpc(
              'ranking_periodo',
              params: {
                'p_desde': desde == null ? null : _fechaIso(desde),
                'p_hasta': hasta == null ? null : _fechaIso(hasta),
              },
            )
            as List;
    return rows
        .map((r) => RankingEntry.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  String _fechaIso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
