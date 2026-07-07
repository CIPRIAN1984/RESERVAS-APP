// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ranking_entry.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_RankingEntry _$RankingEntryFromJson(Map<String, dynamic> json) =>
    _RankingEntry(
      alumnoId: json['alumno_id'] as String,
      nombre: json['nombre'] as String,
      apellidos: json['apellidos'] as String?,
      fotoUrl: json['foto_url'] as String?,
      cinturon: json['cinturon'] as String?,
      asistenciasCount: (json['asistencias_count'] as num).toInt(),
    );

Map<String, dynamic> _$RankingEntryToJson(_RankingEntry instance) =>
    <String, dynamic>{
      'alumno_id': instance.alumnoId,
      'nombre': instance.nombre,
      'apellidos': instance.apellidos,
      'foto_url': instance.fotoUrl,
      'cinturon': instance.cinturon,
      'asistencias_count': instance.asistenciasCount,
    };
