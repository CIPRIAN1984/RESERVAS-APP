import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import 'documento_alumno.dart';

class DocumentosRepository {
  DocumentosRepository(this._client);

  final sb.SupabaseClient _client;

  static const _bucket = 'documentos-alumnos';

  Future<List<DocumentoAlumno>> listarPorAlumno(String alumnoId) async {
    final rows = await _client
        .from('documentos_alumno')
        .select()
        .eq('alumno_id', alumnoId);
    return rows.map(DocumentoAlumno.fromJson).toList();
  }

  /// Sube (o reemplaza, si ya había uno) el documento de `tipo` para
  /// `alumnoId`. Puede llamarlo el propio alumno, su tutor, o el staff de
  /// su academia dando de alta un justificante en papel — la RLS decide
  /// quién puede de verdad.
  Future<void> subir({
    required String alumnoId,
    required String tipo,
    required String subidoPor,
    required Uint8List bytes,
    required String fileExtension,
  }) async {
    final path = '$alumnoId/$tipo.$fileExtension';
    await _client.storage
        .from(_bucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions: const sb.FileOptions(upsert: true),
        );

    await _client.from('documentos_alumno').upsert({
      'alumno_id': alumnoId,
      'tipo': tipo,
      'storage_path': path,
      'subido_por': subidoPor,
    }, onConflict: 'alumno_id,tipo');
  }

  /// URL de corta duración para ver o descargar el documento. El bucket es
  /// privado: no hay URL pública posible, y esta respeta la misma RLS que
  /// protege la fila en `documentos_alumno`.
  Future<String> urlFirmada(String storagePath) {
    return _client.storage.from(_bucket).createSignedUrl(storagePath, 300);
  }

  /// Solo el staff de la academia (o el Administrador) puede borrar: lo
  /// decide la RLS de `documentos_alumno` y de `storage.objects`.
  Future<void> borrar({
    required String alumnoId,
    required String tipo,
    required String storagePath,
  }) async {
    await _client
        .from('documentos_alumno')
        .delete()
        .eq('alumno_id', alumnoId)
        .eq('tipo', tipo);
    await _client.storage.from(_bucket).remove([storagePath]);
  }
}
