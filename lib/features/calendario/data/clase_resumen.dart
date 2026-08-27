import 'package:freezed_annotation/freezed_annotation.dart';

part 'clase_resumen.freezed.dart';
part 'clase_resumen.g.dart';

/// Row returned by the `listar_clases_semana` RPC — a class occurrence
/// enriched with the teacher's name, live headcount and the caller's own
/// enrollment status, all resolved server-side in a single query.
@freezed
abstract class ClaseResumen with _$ClaseResumen {
  const ClaseResumen._();

  const factory ClaseResumen({
    required String id,
    required String titulo,
    String? descripcion,
    @JsonKey(name: 'fecha_hora_inicio') required DateTime fechaHoraInicio,
    @JsonKey(name: 'fecha_hora_fin') required DateTime fechaHoraFin,
    @JsonKey(name: 'aforo_maximo') required int aforoMaximo,
    @JsonKey(name: 'profesor_id') required String profesorId,
    @JsonKey(name: 'profesor_nombre') required String profesorNombre,
    @JsonKey(name: 'inscritos_count') required int inscritosCount,
    @JsonKey(name: 'mi_estado') String? miEstado,
    @Default('activa') String estado,
    @JsonKey(name: 'pendientes_confirmar') @Default(0) int pendientesConfirmar,
  }) = _ClaseResumen;

  factory ClaseResumen.fromJson(Map<String, dynamic> json) =>
      _$ClaseResumenFromJson(json);

  bool get estoyInscrito => miEstado == 'inscrito';
  bool get enListaEspera => miEstado == 'espera';
  bool get tieneReservaActiva => estoyInscrito || enListaEspera;
  bool get aforoCompleto => inscritosCount >= aforoMaximo;

  bool get activa => estado == 'activa';
  bool get cerrada => estado == 'cerrada';
  bool get cancelada => estado == 'cancelada';
}
