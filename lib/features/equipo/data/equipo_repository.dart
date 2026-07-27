import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../core/models/profile.dart';

class EquipoRepository {
  EquipoRepository(this._client);

  final sb.SupabaseClient _client;

  Future<List<Profile>> listMiembros(String academiaId) async {
    final rows = await _client
        .from('profiles')
        .select()
        .eq('academia_id', academiaId)
        .order('nombre');

    final miembros = (rows as List)
        .map((row) => Profile.fromJson(row as Map<String, dynamic>))
        .toList();

    const ordenRol = {'dueño': 0, 'profesor': 1, 'alumno': 2};
    miembros.sort((a, b) {
      final porRol = (ordenRol[a.rol] ?? 3).compareTo(ordenRol[b.rol] ?? 3);
      if (porRol != 0) return porRol;
      return a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase());
    });
    return miembros;
  }

  Future<void> cambiarRol({
    required String miembroId,
    required String nuevoRol,
  }) async {
    await _client.rpc(
      'cambiar_rol_miembro',
      params: {
        'p_miembro_id': miembroId,
        'p_nuevo_rol': nuevoRol,
      },
    );
  }
}
