import 'package:freezed_annotation/freezed_annotation.dart';

part 'clase_resumen.freezed.dart';
part 'clase_resumen.g.dart';

/// La reserva de un hijo en una clase, tal y como la devuelve
/// `listar_clases_semana` en `reservas_familia`.
///
/// Solo los hijos: lo del propio usuario sigue viniendo en `mi_estado`. Son
/// dos cosas distintas y la tarjeta las pinta en sitios distintos.
@freezed
abstract class ReservaFamiliar with _$ReservaFamiliar {
  const factory ReservaFamiliar({
    @JsonKey(name: 'alumno_id') required String alumnoId,
    required String estado,
  }) = _ReservaFamiliar;

  factory ReservaFamiliar.fromJson(Map<String, dynamic> json) =>
      _$ReservaFamiliarFromJson(json);
}

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
    @JsonKey(name: 'reservas_familia')
    @Default(<ReservaFamiliar>[])
    List<ReservaFamiliar> reservasFamilia,
  }) = _ClaseResumen;

  factory ClaseResumen.fromJson(Map<String, dynamic> json) =>
      _$ClaseResumenFromJson(json);

  bool get estoyInscrito => miEstado == 'inscrito';
  bool get enListaEspera => miEstado == 'espera';
  bool get tieneReservaActiva => estoyInscrito || enListaEspera;
  bool get aforoCompleto => inscritosCount >= aforoMaximo;

  /// El estado de [alumnoId] en esta clase: el mío si es el mío, el de un
  /// hijo si lo es, y `null` si esa persona no tiene nada aquí.
  ///
  /// [miId] se pasa aparte porque lo propio no viene en `reservas_familia`:
  /// el servidor lo devuelve en `mi_estado`.
  String? estadoDe(String alumnoId, {required String? miId}) {
    if (alumnoId == miId) return miEstado;
    for (final r in reservasFamilia) {
      if (r.alumnoId == alumnoId) return r.estado;
    }
    return null;
  }

  /// Cuántos hijos tienen plaza o esperan sitio en esta clase.
  int get hijosApuntados => reservasFamilia.length;

  bool get activa => estado == 'activa';
  bool get cerrada => estado == 'cerrada';
  bool get cancelada => estado == 'cancelada';
}
