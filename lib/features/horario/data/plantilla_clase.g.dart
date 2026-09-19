// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'plantilla_clase.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_PlantillaClase _$PlantillaClaseFromJson(Map<String, dynamic> json) =>
    _PlantillaClase(
      id: json['id'] as String,
      academiaId: json['academia_id'] as String,
      profesorId: json['profesor_id'] as String,
      profesorNombre: json['profesor_nombre'] as String,
      titulo: json['titulo'] as String,
      descripcion: json['descripcion'] as String?,
      diaSemana: (json['dia_semana'] as num).toInt(),
      horaInicio: json['hora_inicio'] as String,
      duracionMin: (json['duracion_min'] as num).toInt(),
      aforoMaximo: (json['aforo_maximo'] as num).toInt(),
      activo: json['activo'] as bool,
    );

Map<String, dynamic> _$PlantillaClaseToJson(_PlantillaClase instance) =>
    <String, dynamic>{
      'id': instance.id,
      'academia_id': instance.academiaId,
      'profesor_id': instance.profesorId,
      'profesor_nombre': instance.profesorNombre,
      'titulo': instance.titulo,
      'descripcion': instance.descripcion,
      'dia_semana': instance.diaSemana,
      'hora_inicio': instance.horaInicio,
      'duracion_min': instance.duracionMin,
      'aforo_maximo': instance.aforoMaximo,
      'activo': instance.activo,
    };
