import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_state.dart';
import '../../../core/models/profile.dart';
import '../../../core/supabase/supabase_client.dart';
import '../data/familia_repository.dart';
import '../data/profile_repository.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(AppSupabase.client);
});

final familiaRepositoryProvider = Provider<FamiliaRepository>((ref) {
  return FamiliaRepository(AppSupabase.client);
});

/// Lista los hijos del usuario actual.
///
/// No se descarta al salir de la pantalla, así que tiene que depender del
/// usuario conectado: si no, al cerrar sesión y entrar otra persona en el
/// mismo móvil, veía los hijos de la cuenta anterior (auditoría del
/// 30/09/2026). La prueba `datos_de_sesion_test.dart` lo vigila.
final hijosProvider = FutureProvider<List<Profile>>((ref) async {
  ref.watch(currentUserIdProvider);
  return ref.watch(familiaRepositoryProvider).listarHijos();
});

/// De esos hijos, cuáles se pueden borrar todavía: los que no han empezado.
///
/// Va aparte del listado a propósito. El listado ya funciona y se usa en
/// tres sitios (Mi familia, el calendario y la hoja «¿Quién viene?»); meterle
/// dentro un dato que solo necesita una pantalla habría obligado a tocar los
/// tres para nada.
final hijosBorrablesProvider = FutureProvider<Set<String>>((ref) async {
  ref.watch(currentUserIdProvider);
  return ref.watch(familiaRepositoryProvider).hijosBorrables();
});
