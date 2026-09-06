import 'package:flutter_riverpod/flutter_riverpod.dart';

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
final hijosProvider = FutureProvider<List<Profile>>((ref) async {
  return ref.watch(familiaRepositoryProvider).listarHijos();
});

/// De esos hijos, cuáles se pueden borrar todavía: los que no han empezado.
///
/// Va aparte del listado a propósito. El listado ya funciona y se usa en
/// tres sitios (Mi familia, el calendario y la hoja «¿Quién viene?»); meterle
/// dentro un dato que solo necesita una pantalla habría obligado a tocar los
/// tres para nada.
final hijosBorrablesProvider = FutureProvider<Set<String>>((ref) async {
  return ref.watch(familiaRepositoryProvider).hijosBorrables();
});
