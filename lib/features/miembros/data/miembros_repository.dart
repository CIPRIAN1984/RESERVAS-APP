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
  /// comprueba `reservar_clase` en el servidor: activa, cobrada y dentro de
  /// fechas. Si aquí se relajaran, Miembros diría «al día» de alguien a
  /// quien el servidor considera moroso — el mismo criterio que ya usa
  /// `ClasesRepository._alumnosConCuotaAlDia`.
  Future<Set<String>> alumnosConCuotaAlDia(String academiaId) async {
    final ahora = DateTime.now().toUtc().toIso8601String();
    final rows =
        await _client
                .from('suscripciones')
                .select('alumno_id')
                .eq('academia_id', academiaId)
                .eq('estado', 'activa')
                .eq('payment_status', 'active')
                .lte('fecha_inicio', ahora)
                .or('fecha_fin.is.null,fecha_fin.gt.$ahora')
            as List;
    return rows
        .cast<Map<String, dynamic>>()
        .map((row) => row['alumno_id'] as String)
        .toSet();
  }
}
