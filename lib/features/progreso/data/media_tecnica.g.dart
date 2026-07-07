// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'media_tecnica.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_MediaTecnica _$MediaTecnicaFromJson(Map<String, dynamic> json) =>
    _MediaTecnica(
      id: json['id'] as String,
      tecnicaId: json['tecnica_id'] as String,
      tipo: json['tipo'] as String,
      url: json['url'] as String,
      subidoPor: json['subido_por'] as String,
    );

Map<String, dynamic> _$MediaTecnicaToJson(_MediaTecnica instance) =>
    <String, dynamic>{
      'id': instance.id,
      'tecnica_id': instance.tecnicaId,
      'tipo': instance.tipo,
      'url': instance.url,
      'subido_por': instance.subidoPor,
    };
