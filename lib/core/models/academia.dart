import 'package:freezed_annotation/freezed_annotation.dart';

import 'academia_estado.dart';

part 'academia.freezed.dart';
part 'academia.g.dart';

@freezed
abstract class Academia with _$Academia {
  const Academia._();

  const factory Academia({
    required String id,
    required String nombre,
    String? direccion,
    String? telefono,
    @JsonKey(name: 'email_contacto') String? emailContacto,
    required String estado,
    @JsonKey(name: 'created_by') String? createdBy,
    @JsonKey(name: 'stripe_onboarding_status') @Default('not_started') String stripeOnboardingStatus,
    @JsonKey(name: 'stripe_charges_enabled') @Default(false) bool stripeChargesEnabled,
  }) = _Academia;

  factory Academia.fromJson(Map<String, dynamic> json) => _$AcademiaFromJson(json);

  AcademiaEstado get estadoEnum => AcademiaEstadoX.fromValue(estado);
}

/// Lightweight option used to populate the "join an existing academia" picker
/// during registration, returned by the narrow `listar_academias_aprobadas` RPC.
typedef AcademiaOption = ({String id, String nombre});
