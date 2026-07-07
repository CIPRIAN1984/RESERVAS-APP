import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import 'ranking_entry.dart';

class EstadisticasRepository {
  EstadisticasRepository(this._client);

  final sb.SupabaseClient _client;

  Future<List<RankingEntry>> rankingMensual(DateTime mes) async {
    final mesIso =
        '${mes.year.toString().padLeft(4, '0')}-${mes.month.toString().padLeft(2, '0')}-01';
    final rows =
        await _client.rpc('ranking_mensual', params: {'p_mes': mesIso}) as List;
    return rows
        .map((r) => RankingEntry.fromJson(r as Map<String, dynamic>))
        .toList();
  }
}
