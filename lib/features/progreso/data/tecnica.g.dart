// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tecnica.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Tecnica _$TecnicaFromJson(Map<String, dynamic> json) => _Tecnica(
  id: json['id'] as String,
  academiaId: json['academia_id'] as String,
  cinturon: json['cinturon'] as String,
  nombre: json['nombre'] as String,
  descripcion: json['descripcion'] as String?,
  orden: (json['orden'] as num).toInt(),
);

Map<String, dynamic> _$TecnicaToJson(_Tecnica instance) => <String, dynamic>{
  'id': instance.id,
  'academia_id': instance.academiaId,
  'cinturon': instance.cinturon,
  'nombre': instance.nombre,
  'descripcion': instance.descripcion,
  'orden': instance.orden,
};
