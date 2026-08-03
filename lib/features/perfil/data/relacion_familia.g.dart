// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'relacion_familia.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_RelacionFamilia _$RelacionFamiliaFromJson(Map<String, dynamic> json) =>
    _RelacionFamilia(
      id: json['id'] as String,
      parentId: json['parent_id'] as String,
      childId: json['child_id'] as String,
      tipoRelacion: json['tipo_relacion'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );

Map<String, dynamic> _$RelacionFamiliaToJson(_RelacionFamilia instance) =>
    <String, dynamic>{
      'id': instance.id,
      'parent_id': instance.parentId,
      'child_id': instance.childId,
      'tipo_relacion': instance.tipoRelacion,
      'created_at': instance.createdAt.toIso8601String(),
    };
