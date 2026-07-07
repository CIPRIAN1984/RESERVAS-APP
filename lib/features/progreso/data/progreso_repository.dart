import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import 'media_tecnica.dart';
import 'tecnica.dart';

typedef AlumnoOption = ({String id, String nombre});

class ProgresoRepository {
  ProgresoRepository(this._client);

  final sb.SupabaseClient _client;

  Future<List<Tecnica>> listarTecnicas() async {
    final rows = await _client.from('tecnicas').select().order('orden') as List;
    final tecnicas = rows
        .map((r) => Tecnica.fromJson(r as Map<String, dynamic>))
        .toList();
    tecnicas.sort((a, b) {
      final cmpCinturon = ordenCinturones
          .indexOf(a.cinturon)
          .compareTo(ordenCinturones.indexOf(b.cinturon));
      return cmpCinturon != 0 ? cmpCinturon : a.orden.compareTo(b.orden);
    });
    return tecnicas;
  }

  /// tecnica_id -> estado, for the given student.
  Future<Map<String, String>> miProgreso(String alumnoId) async {
    final rows =
        await _client
                .from('progreso_alumno_tecnica')
                .select('tecnica_id, estado')
                .eq('alumno_id', alumnoId)
            as List;
    return {
      for (final r in rows)
        (r as Map<String, dynamic>)['tecnica_id'] as String:
            r['estado'] as String,
    };
  }

  Future<List<MediaTecnica>> listarMedia(String tecnicaId) async {
    final rows =
        await _client
                .from('media_tecnica')
                .select()
                .eq('tecnica_id', tecnicaId)
                .order('created_at')
            as List;
    return rows
        .map((r) => MediaTecnica.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  Future<void> crearTecnica({
    required String academiaId,
    required String cinturon,
    required String nombre,
    String? descripcion,
    required int orden,
  }) async {
    await _client.from('tecnicas').insert({
      'academia_id': academiaId,
      'cinturon': cinturon,
      'nombre': nombre,
      'descripcion': descripcion,
      'orden': orden,
    });
  }

  Future<void> agregarMedia({
    required String tecnicaId,
    required String tipo,
    required String url,
    required String subidoPor,
  }) async {
    await _client.from('media_tecnica').insert({
      'tecnica_id': tecnicaId,
      'tipo': tipo,
      'url': url,
      'subido_por': subidoPor,
    });
  }

  Future<void> marcarProgreso({
    required String alumnoId,
    required String tecnicaId,
    required String estado,
  }) async {
    await _client
        .from('progreso_alumno_tecnica')
        .update({
          'estado': estado,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('alumno_id', alumnoId)
        .eq('tecnica_id', tecnicaId);
  }

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
}
