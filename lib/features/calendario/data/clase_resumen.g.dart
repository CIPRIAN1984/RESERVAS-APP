// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'clase_resumen.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ClaseResumen _$ClaseResumenFromJson(Map<String, dynamic> json) =>
    _ClaseResumen(
      id: json['id'] as String,
      titulo: json['titulo'] as String,
      descripcion: json['descripcion'] as String?,
      fechaHoraInicio: DateTime.parse(json['fecha_hora_inicio'] as String),
      fechaHoraFin: DateTime.parse(json['fecha_hora_fin'] as String),
      aforoMaximo: (json['aforo_maximo'] as num).toInt(),
      profesorId: json['profesor_id'] as String,
      profesorNombre: json['profesor_nombre'] as String,
      inscritosCount: (json['inscritos_count'] as num).toInt(),
      miEstado: json['mi_estado'] as String?,
      estado: json['estado'] as String? ?? 'activa',
    );

Map<String, dynamic> _$ClaseResumenToJson(_ClaseResumen instance) =>
    <String, dynamic>{
      'id': instance.id,
      'titulo': instance.titulo,
      'descripcion': instance.descripcion,
      'fecha_hora_inicio': instance.fechaHoraInicio.toIso8601String(),
      'fecha_hora_fin': instance.fechaHoraFin.toIso8601String(),
      'aforo_maximo': instance.aforoMaximo,
      'profesor_id': instance.profesorId,
      'profesor_nombre': instance.profesorNombre,
      'inscritos_count': instance.inscritosCount,
      'mi_estado': instance.miEstado,
      'estado': instance.estado,
    };
