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
