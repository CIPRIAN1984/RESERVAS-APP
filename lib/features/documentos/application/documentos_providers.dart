import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_client.dart';
import '../data/documento_alumno.dart';
import '../data/documentos_repository.dart';

final documentosRepositoryProvider = Provider<DocumentosRepository>((ref) {
  return DocumentosRepository(AppSupabase.client);
});

/// Los documentos de un alumno concreto (como mucho dos: certificado médico
/// y descargo de responsabilidad). Lo usan tanto la pantalla del propio
/// alumno/tutor como la ficha que ve el staff.
final documentosDeProvider = FutureProvider.autoDispose
    .family<List<DocumentoAlumno>, String>((ref, alumnoId) {
      return ref.watch(documentosRepositoryProvider).listarPorAlumno(alumnoId);
    });
