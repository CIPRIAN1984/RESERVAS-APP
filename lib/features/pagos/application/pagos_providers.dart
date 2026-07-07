import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_client.dart';
import '../data/pagos_repository.dart';

final pagosRepositoryProvider = Provider<PagosRepository>((ref) {
  return PagosRepository(AppSupabase.client);
});
