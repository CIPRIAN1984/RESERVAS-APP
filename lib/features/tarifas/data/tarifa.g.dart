// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tarifa.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Tarifa _$TarifaFromJson(Map<String, dynamic> json) => _Tarifa(
  id: json['id'] as String,
  academiaId: json['academia_id'] as String,
  nombre: json['nombre'] as String,
  descripcion: json['descripcion'] as String?,
  precio: json['precio'] as num,
  periodicidad: json['periodicidad'] as String,
  activo: json['activo'] as bool,
);

Map<String, dynamic> _$TarifaToJson(_Tarifa instance) => <String, dynamic>{
  'id': instance.id,
  'academia_id': instance.academiaId,
  'nombre': instance.nombre,
  'descripcion': instance.descripcion,
  'precio': instance.precio,
  'periodicidad': instance.periodicidad,
  'activo': instance.activo,
};
