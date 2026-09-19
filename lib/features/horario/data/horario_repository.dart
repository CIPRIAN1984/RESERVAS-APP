import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import 'plantilla_clase.dart';

/// El horario fijo de la academia: los huecos que se repiten cada semana.
///
/// Todo pasa por permisos que ya existían (`clases_recurrentes` solo la
/// tocan Profesor y Dueño de su propia academia — migración de clases
/// recurrentes de agosto de 2026): esta pantalla no ha necesitado ninguna
/// migración nueva, solo enseñar y escribir en lo que el servidor ya
/// permitía.
class HorarioRepository {
  HorarioRepository(this._client);

  final sb.SupabaseClient _client;

  Future<List<PlantillaClase>> listarPlantillas(String academiaId) async {
    final rows =
        await _client
                .from('clases_recurrentes')
                .select(
                  'id, academia_id, profesor_id, titulo, descripcion, '
                  'dia_semana, hora_inicio, duracion_min, aforo_maximo, activo, '
                  'profesor:profiles(nombre, apellidos)',
                )
                .eq('academia_id', academiaId)
                .order('dia_semana')
                .order('hora_inicio')
            as List;
    return rows.cast<Map<String, dynamic>>().map(_conNombreProfesor).toList();
  }

  /// El join trae `profesor` como un mapa aparte; aquí se aplana a
  /// `profesor_nombre`, que es lo que espera [PlantillaClase.fromJson].
  PlantillaClase _conNombreProfesor(Map<String, dynamic> row) {
    final profesor = row['profesor'] as Map<String, dynamic>?;
    final nombre = [
      profesor?['nombre'],
      profesor?['apellidos'],
    ].whereType<String>().where((s) => s.isNotEmpty).join(' ');
    return PlantillaClase.fromJson({
      ...row,
      'profesor_nombre': nombre.isEmpty ? 'Sin asignar' : nombre,
    });
  }

  Future<void> crearPlantilla({
    required String academiaId,
    required String profesorId,
    required String titulo,
    String? descripcion,
    required int diaSemana,
    required String horaInicio,
    required int duracionMin,
    required int aforoMaximo,
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
    // Materializa las próximas semanas ya mismo: si no, el hueco nuevo no
    // aparecería en el calendario hasta el lunes que viene, cuando corra el
    // trabajo programado.
    await generarAhora();
  }

  /// Cambia un hueco que ya existe. **Solo afecta a lo que se genere de
  /// aquí en adelante**: las clases de las próximas semanas que ya estén
  /// creadas no cambian solas (se generan una vez y no se vuelven a tocar,
  /// igual que pasa si editas una clase suelta). Si hace falta cambiar
  /// alguna ya creada, se edita esa clase concreta desde el calendario.
  Future<void> editarPlantilla({
    required String plantillaId,
    required String titulo,
    String? descripcion,
    required int diaSemana,
    required String horaInicio,
    required int duracionMin,
    required int aforoMaximo,
  }) async {
    await _client
        .from('clases_recurrentes')
        .update({
          'titulo': titulo,
          'descripcion': descripcion,
          'dia_semana': diaSemana,
          'hora_inicio': horaInicio,
          'duracion_min': duracionMin,
          'aforo_maximo': aforoMaximo,
        })
        .eq('id', plantillaId);
  }

  Future<void> alternarActivo(String plantillaId, bool activo) async {
    await _client
        .from('clases_recurrentes')
        .update({'activo': activo})
        .eq('id', plantillaId);
    // Pausar no borra lo ya generado (esas clases se cancelan a mano si
    // hace falta); reactivar sí debe rellenar el hueco de golpe, no esperar
    // al lunes.
    if (activo) await generarAhora();
  }

  /// Convierte en clases de verdad lo que toque de las plantillas activas,
  /// para las próximas ~4 semanas. Es lo mismo que hace el trabajo
  /// programado cada lunes; llamarlo aquí es solo para no obligar a
  /// esperar a que llegue ese día.
  Future<int> generarAhora() async {
    final generadas = await _client.rpc('generar_mis_clases_recurrentes');
    return (generadas as int?) ?? 0;
  }
}
