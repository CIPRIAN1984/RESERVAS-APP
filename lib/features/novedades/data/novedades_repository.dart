import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import 'novedad.dart';

class NovedadesRepository {
  NovedadesRepository(this._client);

  final sb.SupabaseClient _client;

  Future<List<Novedad>> listar() async {
    final rows =
        await _client
                .from('novedades')
                .select('*, autor:profiles(nombre)')
                .order('fijado', ascending: false)
                .order('created_at', ascending: false)
            as List;
    return rows.map((r) => Novedad.fromRow(r as Map<String, dynamic>)).toList();
  }

  Future<void> crear({
    required String academiaId,
    required String autorId,
    required String titulo,
    required String contenido,
  }) async {
    await _client.from('novedades').insert({
      'academia_id': academiaId,
      'autor_id': autorId,
      'titulo': titulo,
      'contenido': contenido,
    });
  }

  Future<void> alternarFijado(String id, bool fijado) async {
    await _client.from('novedades').update({'fijado': fijado}).eq('id', id);
  }

  Future<void> eliminar(String id) async {
    await _client.from('novedades').delete().eq('id', id);
  }
}
