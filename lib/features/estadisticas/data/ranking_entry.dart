import 'package:freezed_annotation/freezed_annotation.dart';

part 'ranking_entry.freezed.dart';
part 'ranking_entry.g.dart';

/// One row of the `ranking_mensual` RPC result.
@freezed
abstract class RankingEntry with _$RankingEntry {
  const RankingEntry._();

  const factory RankingEntry({
    @JsonKey(name: 'alumno_id') required String alumnoId,
    required String nombre,
    String? apellidos,
    @JsonKey(name: 'foto_url') String? fotoUrl,
    String? cinturon,
    @JsonKey(name: 'asistencias_count') required int asistenciasCount,
  }) = _RankingEntry;

  factory RankingEntry.fromJson(Map<String, dynamic> json) => _$RankingEntryFromJson(json);

  String get nombreCompleto => [nombre, apellidos].whereType<String>().join(' ');
}
