import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../core/models/profile.dart';
import 'relacion_familia.dart';

class FamiliaRepository {
  FamiliaRepository(this._client);

  final sb.SupabaseClient _client;

  /// Lista todos los hijos del usuario actual (via relaciones_familia).
  Future<List<Profile>> listarHijos() async {
    final relaciones = await _client
        .from('relaciones_familia')
        .select('child_id')
        .eq('parent_id', _client.auth.currentUser!.id) as List;

    if (relaciones.isEmpty) return [];

    final childIds =
        relaciones.cast<Map<String, dynamic>>().map((r) => r['child_id'] as String).toList();

    final hijos = await _client
        .from('profiles')
        .select()
        .inFilter('id', childIds) as List;

    return hijos
        .map((h) => Profile.fromJson(h as Map<String, dynamic>))
        .toList();
  }

  /// Crea un nuevo hijo llamando a la Edge Function.
  /// Devuelve el ID del perfil creado y la relación familia.
  Future<({String childId, String familiaId})> crearHijo({
    required String nombre,
    String? apellidos,
    String? cinturon,
  }) async {
    final response = await _client.functions.invoke(
      'crear-hijo',
      body: {
        'nombre': nombre,
        'apellidos': apellidos,
        'cinturon': cinturon,
      },
    );

    final data = response.data as Map<String, dynamic>;
    if (data['error'] != null) throw Exception(data['error'] as String);

    return (
      childId: data['hijo_id'] as String,
      familiaId: data['familia_id'] as String,
    );
  }

  /// Actualiza datos del hijo (nombre, apellidos, cinturón).
  /// El hijo debe tener parent_id = auth.uid() en relaciones_familia.
  Future<void> actualizarHijo({
    required String childId,
    required String nombre,
    String? apellidos,
    String? cinturon,
  }) async {
    await _client
        .from('profiles')
        .update({
          'nombre': nombre,
          'apellidos': apellidos,
          'cinturon': cinturon,
        })
        .eq('id', childId);
  }

  /// Elimina la relación familia (el padre deja de tener potestad).
  /// Nota: el perfil del menor sigue existiendo; solo se rompe la relación.
  Future<void> eliminarHijo(String childId) async {
    await _client
        .from('relaciones_familia')
        .delete()
        .eq('child_id', childId);
  }

  /// Obtiene la relación familia (si existe).
  Future<RelacionFamilia?> obtenerRelacion(String childId) async {
    final row = await _client
        .from('relaciones_familia')
        .select()
        .eq('child_id', childId)
        .maybeSingle();

    if (row == null) return null;
    return RelacionFamilia.fromJson(row as Map<String, dynamic>);
  }
}
