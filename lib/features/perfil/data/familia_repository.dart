import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../core/models/profile.dart';

/// Los hijos de un padre o tutor.
///
/// Reescrito el 04/09/2026. La versión anterior llamaba a una Edge Function
/// (`crear-hijo`) que a su vez invocaba `crear_perfil_hijo`, una función
/// que **no podía funcionar nunca**: insertaba un perfil con un uuid nuevo
/// contra una clave foránea que exigía una cuenta de correo. Se borró en la
/// migración `20260903130000_familias_tutores_v2`.
///
/// Ahora el alta va por una única RPC, `crear_hijo`, que crea el perfil del
/// menor **dentro** de la función: no acepta el id de un perfil ajeno, que
/// es justo lo que permitía el agujero cerrado en la migración
/// `20260903120000`.
class FamiliaRepository {
  FamiliaRepository(this._client);

  final sb.SupabaseClient _client;

  /// Los hijos del usuario que ha iniciado sesión.
  ///
  /// Dos consultas y no un `join` porque la RLS de `relaciones_familia` y la
  /// de `profiles` se comprueban por separado; encadenarlas en un embed de
  /// PostgREST hacía que un fallo de permisos volviera como lista vacía en
  /// vez de como error.
  Future<List<Profile>> listarHijos() async {
    final usuario = _client.auth.currentUser;
    if (usuario == null) return const [];

    final relaciones =
        await _client
                .from('relaciones_familia')
                .select('child_id')
                .eq('parent_id', usuario.id)
            as List;

    if (relaciones.isEmpty) return const [];

    final ids = relaciones
        .cast<Map<String, dynamic>>()
        .map((r) => r['child_id'] as String)
        .toList();

    final hijos =
        await _client
                .from('profiles')
                .select()
                .inFilter('id', ids)
                .order('nombre')
            as List;

    return hijos
        .map((h) => Profile.fromJson(h as Map<String, dynamic>))
        .toList();
  }

  /// Da de alta a un hijo y devuelve su id.
  ///
  /// No se le pide el cinturón al padre a propósito: el menor entra sin
  /// cinturón (que la app enseña como blanco) y quien gradúa es el Dueño,
  /// desde la ficha del alumno. Un padre no tiene por qué conocer la
  /// escala infantil de doce grados.
  Future<String> crearHijo({required String nombre, String? apellidos}) async {
    final id = await _client.rpc(
      'crear_hijo',
      params: {'p_nombre': nombre, 'p_apellidos': apellidos},
    );
    return id as String;
  }

  /// Corrige el nombre de un hijo.
  ///
  /// Solo nombre y apellidos: son las únicas columnas de `profiles` que un
  /// cliente puede escribir (ver la lección de la migración 0013). El
  /// cinturón lo cambia el Dueño con `promover_cinturon`.
  Future<void> renombrarHijo({
    required String hijoId,
    required String nombre,
    String? apellidos,
  }) async {
    await _client
        .from('profiles')
        .update({'nombre': nombre, 'apellidos': apellidos})
        .eq('id', hijoId);
  }
}
