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
    final rows =
        await _client.rpc(
              'listar_clases_semana',
              params: {
                'p_desde': desde.toUtc().toIso8601String(),
                'p_hasta': hasta.toUtc().toIso8601String(),
              },
            )
            as List;
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

  /// Creates a weekly recurring-class template. Concrete sessions are then
  /// materialized into `clases` by the generation job (see
  /// `generar_clases_recurrentes`); [generarAhora] triggers it immediately so
  /// the upcoming weeks appear without waiting for the scheduled run.
  Future<void> crearPlantillaRecurrente({
    required String academiaId,
    required String profesorId,
    required String titulo,
    String? descripcion,
    required int diaSemana, // 0 = domingo
    required String horaInicio, // 'HH:mm'
    required int duracionMin,
    required int aforoMaximo,
    bool generarAhora = true,
  }) async {
    await _client.from('clases_recurrentes').insert({
      'academia_id': academiaId,
      'profesor_id': profesorId,
      'titulo': titulo,
      'descripcion': descripcion,
      'dia_semana': diaSemana,
      'hora_inicio': horaInicio,
      'duracion_min': duracionMin,
      'aforo_maximo': aforoMaximo,
    });
    if (generarAhora) await generarClasesRecurrentes();
  }

  /// Materializes upcoming sessions from this academia's active templates.
  /// Idempotent; scoped to the caller's academia and staff-only server-side.
  Future<int> generarClasesRecurrentes() async {
    final generadas = await _client.rpc('generar_mis_clases_recurrentes');
    return (generadas as int?) ?? 0;
  }

  Future<void> unirse({required String claseId}) async {
    await _client.rpc(
      'reservar_clase',
      params: {'p_clase_id': claseId},
    );
  }

  Future<void> borrarse({required String claseId}) async {
    await _client.rpc(
      'cancelar_reserva',
      params: {'p_clase_id': claseId},
    );
  }

  Future<List<InscritoAlumno>> listarInscritos(String claseId) async {
    final inscripciones =
        await _client
                .from('inscripciones')
                .select(
                  'alumno_id, alumno:profiles(nombre, apellidos, foto_url, cinturon)',
                )
                .eq('clase_id', claseId)
                .eq('estado', 'inscrito')
            as List;

    final asistencias =
        await _client
                .from('asistencias')
                .select('alumno_id')
                .eq('clase_id', claseId)
            as List;
    final validados = asistencias.map((a) => a['alumno_id'] as String).toSet();

    return inscripciones
        .map(
          (row) => InscritoAlumno.fromInscripcionJson(
            row as Map<String, dynamic>,
            asistenciaValidada: validados.contains(row['alumno_id']),
          ),
        )
        .toList();
  }

  Future<void> marcarAsistencia({
    required String claseId,
    required String alumnoId,
    required String validadoPor,
  }) async {
    await _client
        .from('asistencias')
        .upsert(
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
