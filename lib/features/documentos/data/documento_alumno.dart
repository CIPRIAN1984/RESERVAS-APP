import 'package:freezed_annotation/freezed_annotation.dart';

part 'documento_alumno.freezed.dart';
part 'documento_alumno.g.dart';

/// Los dos únicos tipos que pide el lanzamiento: certificado médico y
/// descargo de responsabilidad firmado. Si algún día hace falta otro, se
/// añade aquí y en el `check` de la migración `documentos_alumno`.
const tiposDocumentoAlumno = ['certificado_medico', 'descargo_responsabilidad'];

String etiquetaTipoDocumento(String tipo) => switch (tipo) {
  'certificado_medico' => 'Certificado médico',
  'descargo_responsabilidad' => 'Descargo de responsabilidad',
  _ => tipo,
};

@freezed
abstract class DocumentoAlumno with _$DocumentoAlumno {
  const factory DocumentoAlumno({
    required String id,
    @JsonKey(name: 'academia_id') required String academiaId,
    @JsonKey(name: 'alumno_id') required String alumnoId,
    required String tipo,
    @JsonKey(name: 'storage_path') required String storagePath,
    @JsonKey(name: 'subido_por') required String subidoPor,
    @JsonKey(name: 'created_at') required DateTime createdAt,
  }) = _DocumentoAlumno;

  factory DocumentoAlumno.fromJson(Map<String, dynamic> json) =>
      _$DocumentoAlumnoFromJson(json);
}
