// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'profile.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Profile _$ProfileFromJson(Map<String, dynamic> json) => _Profile(
  id: json['id'] as String,
  academiaId: json['academia_id'] as String?,
  rol: json['rol'] as String,
  nombre: json['nombre'] as String,
  apellidos: json['apellidos'] as String?,
  fotoUrl: json['foto_url'] as String?,
  cinturon: json['cinturon'] as String?,
  estado: json['estado'] as String,
  parentId: json['parent_id'] as String?,
  fechaInicioCinturon: json['fecha_inicio_cinturon'] == null
      ? null
      : DateTime.parse(json['fecha_inicio_cinturon'] as String),
);

Map<String, dynamic> _$ProfileToJson(_Profile instance) => <String, dynamic>{
  'id': instance.id,
  'academia_id': instance.academiaId,
  'rol': instance.rol,
  'nombre': instance.nombre,
  'apellidos': instance.apellidos,
  'foto_url': instance.fotoUrl,
  'cinturon': instance.cinturon,
  'estado': instance.estado,
  'parent_id': instance.parentId,
  'fecha_inicio_cinturon': instance.fechaInicioCinturon?.toIso8601String(),
};
