import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import 'clase_resumen.dart';
import 'inscrito_alumno.dart';

class ClasesRepository {
  ClasesRepository(this._client);

  final sb.SupabaseClient _client;

  Future<List<ClaseResumen>> listarClases({
    required DateTime desde,
    required DateTime hasta,
  }) async {
    final rows = await _client.rpc('listar_clases_semana', params: {
      'p_desde': desde.toUtc().toIso8601String(),
      'p_hasta': hasta.toUtc().toIso8601String(),
    }) as List;
    return rows
        .map((r) => ClaseResumen.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  Future<void> crearClase({
    required String academiaId,
    required String profesorId,
    required String titulo,
    String? descripcion,
    required DateTime fechaHoraInicio,
    required DateTime fechaHoraFin,
    required int aforoMaximo,
  }) async {
    await _client.from('clases').insert({
      'academia_id': academiaId,
      'profesor_id': profesorId,
      'titulo': titulo,
      'descripcion': descripcion,
      'fecha_hora_inicio': fechaHoraInicio.toUtc().toIso8601String(),
      'fecha_hora_fin': fechaHoraFin.toUtc().toIso8601String(),
      'aforo_maximo': aforoMaximo,
    });
  }

  Future<void> unirse({required String claseId, required String alumnoId}) async {
    await _client.from('inscripciones').insert({
      'clase_id': claseId,
      'alumno_id': alumnoId,
      'estado': 'inscrito',
    });
  }

  Future<void> borrarse({required String claseId, required String alumnoId}) async {
    await _client
        .from('inscripciones')
        .update({'estado': 'cancelado'})
        .eq('clase_id', claseId)
        .eq('alumno_id', alumnoId)
        .eq('estado', 'inscrito');
  }

  Future<List<InscritoAlumno>> listarInscritos(String claseId) async {
    final inscripciones = await _client
        .from('inscripciones')
        .select('alumno_id, alumno:profiles(nombre, apellidos, foto_url, cinturon)')
        .eq('clase_id', claseId)
        .eq('estado', 'inscrito') as List;

    final asistencias = await _client
        .from('asistencias')
        .select('alumno_id')
        .eq('clase_id', claseId) as List;
    final validados = asistencias.map((a) => a['alumno_id'] as String).toSet();

    return inscripciones
        .map((row) => InscritoAlumno.fromInscripcionJson(
              row as Map<String, dynamic>,
              asistenciaValidada: validados.contains(row['alumno_id']),
            ))
        .toList();
  }

  Future<void> marcarAsistencia({
    required String claseId,
    required String alumnoId,
    required String validadoPor,
  }) async {
    await _client.from('asistencias').upsert(
      {
        'clase_id': claseId,
        'alumno_id': alumnoId,
        'validado_por': validadoPor,
      },
      onConflict: 'clase_id,alumno_id',
      ignoreDuplicates: true,
    );
  }
}
