// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'producto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Producto _$ProductoFromJson(Map<String, dynamic> json) => _Producto(
  id: json['id'] as String,
  academiaId: json['academia_id'] as String,
  nombre: json['nombre'] as String,
  descripcion: json['descripcion'] as String?,
  precio: json['precio'] as num,
  stock: (json['stock'] as num).toInt(),
  fotoUrl: json['foto_url'] as String?,
  activo: json['activo'] as bool,
);

Map<String, dynamic> _$ProductoToJson(_Producto instance) => <String, dynamic>{
  'id': instance.id,
  'academia_id': instance.academiaId,
  'nombre': instance.nombre,
  'descripcion': instance.descripcion,
  'precio': instance.precio,
  'stock': instance.stock,
  'foto_url': instance.fotoUrl,
  'activo': instance.activo,
};
