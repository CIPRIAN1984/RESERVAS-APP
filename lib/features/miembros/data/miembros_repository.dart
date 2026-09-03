import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../core/models/profile.dart';

class MiembrosRepository {
  MiembrosRepository(this._client);

  final sb.SupabaseClient _client;

  Future<List<Profile>> listarAlumnos(String academiaId) async {
    final rows =
        await _client
                .from('profiles')
                .select()
                .eq('academia_id', academiaId)
                .eq('rol', 'alumno')
                .order('nombre')
            as List;
    return rows
        .map((row) => Profile.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  /// Quién tiene la cuota al día, con **las mismas condiciones** que
  /// comprueba `reservar_clase` en el servidor: activa o en prueba, cobrada
  /// y dentro de fechas. Si aquí se relajaran, Miembros diría «al día» de
  /// alguien a quien el servidor considera moroso — el mismo criterio que
  /// ya usa `ClasesRepository._alumnosConCuotaAlDia`.
  Future<Set<String>> alumnosConCuotaAlDia(String academiaId) async {
    final ahora = DateTime.now().toUtc().toIso8601String();
    final rows =
        await _client
                .from('suscripciones')
                .select('alumno_id')
                .eq('academia_id', academiaId)
                .inFilter('estado', ['activa', 'prueba'])
                .eq('payment_status', 'active')
                .lte('fecha_inicio', ahora)
                .or('fecha_fin.is.null,fecha_fin.gt.$ahora')
            as List;
    return rows
        .cast<Map<String, dynamic>>()
        .map((row) => row['alumno_id'] as String)
        .toSet();
  }

  /// Cuándo entrenó cada alumno por última vez, indexado por alumno.
  ///
  /// Quien no aparece en el mapa no tiene ninguna asistencia registrada —
  /// nunca ha venido a clase. La RPC ya limita el resultado a la propia
  /// academia (`current_academia_id()`) y solo cuenta a quien tiene rol
  /// Alumno, no al Profesor o Dueño que entrena con ellos.
  Future<Map<String, DateTime>> ultimaAsistenciaPorAlumno() async {
    final rows = await _client.rpc('ultima_asistencia_por_alumno') as List;
    return {
      for (final row in rows.cast<Map<String, dynamic>>())
        row['alumno_id'] as String: DateTime.parse(
          row['ultima_asistencia'] as String,
        ),
    };
  }

  /// `true` si el alumno tiene un padre/tutor registrado — es un menor, así
  /// que su progresión de cinturón sigue la escala infantil (ver
  /// `progreso_cinturon.dart`). RLS de `relaciones_familia` ya limita esta
  /// consulta a la propia academia.
  Future<bool> esMenor(String alumnoId) async {
    final rows =
        await _client
                .from('relaciones_familia')
                .select('id')
                .eq('child_id', alumnoId)
                .limit(1)
            as List;
    return rows.isNotEmpty;
  }

  /// Cuántos entrenos lleva cada alumno desde que empezó su cinturón
  /// actual, y si es menor de edad — los dos datos en bruto que hacen
  /// falta para saber quién está listo para graduarse, para toda la
  /// academia en un único viaje (ver `progreso_graduacion_alumnos`; la
  /// misma cuenta que hace [contarAsistenciasDesde] + [esMenor] uno a uno,
  /// pero de golpe: con 166 alumnos, una consulta por fila sería lenta).
  Future<Map<String, ({int asistencias, bool esMenor})>>
  progresoGraduacionAlumnos() async {
    final rows = await _client.rpc('progreso_graduacion_alumnos') as List;
    return {
      for (final row in rows.cast<Map<String, dynamic>>())
        row['alumno_id'] as String: (
          asistencias: (row['asistencias'] as num).toInt(),
          esMenor: row['es_menor'] as bool,
        ),
    };
  }

  /// Entrenos acumulados desde [desde] — para el progreso hacia el
  /// siguiente cinturón.
  Future<int> contarAsistenciasDesde(String alumnoId, DateTime desde) async {
    final rows =
        await _client
                .from('asistencias')
                .select('id')
                .eq('alumno_id', alumnoId)
                .gte('fecha', desde.toUtc().toIso8601String())
            as List;
    return rows.length;
  }

  /// Cambia el cinturón del alumno y reinicia su contador de entrenos.
  /// Server-side: `promover_cinturon` exige Profesor/Dueño activo de la
  /// misma academia.
  Future<void> promoverCinturon({
    required String alumnoId,
    required String nuevoCinturon,
  }) async {
    await _client.rpc(
      'promover_cinturon',
      params: {'p_alumno_id': alumnoId, 'p_nuevo_cinturon': nuevoCinturon},
    );
  }
}
