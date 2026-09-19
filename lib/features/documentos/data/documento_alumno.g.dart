// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'documento_alumno.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_DocumentoAlumno _$DocumentoAlumnoFromJson(Map<String, dynamic> json) =>
    _DocumentoAlumno(
      id: json['id'] as String,
      academiaId: json['academia_id'] as String,
      alumnoId: json['alumno_id'] as String,
      tipo: json['tipo'] as String,
      storagePath: json['storage_path'] as String,
      subidoPor: json['subido_por'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );

Map<String, dynamic> _$DocumentoAlumnoToJson(_DocumentoAlumno instance) =>
    <String, dynamic>{
      'id': instance.id,
      'academia_id': instance.academiaId,
      'alumno_id': instance.alumnoId,
      'tipo': instance.tipo,
      'storage_path': instance.storagePath,
      'subido_por': instance.subidoPor,
      'created_at': instance.createdAt.toIso8601String(),
    };
