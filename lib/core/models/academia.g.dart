// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'academia.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Academia _$AcademiaFromJson(Map<String, dynamic> json) => _Academia(
  id: json['id'] as String,
  nombre: json['nombre'] as String,
  direccion: json['direccion'] as String?,
  telefono: json['telefono'] as String?,
  emailContacto: json['email_contacto'] as String?,
  estado: json['estado'] as String,
  createdBy: json['created_by'] as String?,
  stripeOnboardingStatus:
      json['stripe_onboarding_status'] as String? ?? 'not_started',
  stripeChargesEnabled: json['stripe_charges_enabled'] as bool? ?? false,
);

Map<String, dynamic> _$AcademiaToJson(_Academia instance) => <String, dynamic>{
  'id': instance.id,
  'nombre': instance.nombre,
  'direccion': instance.direccion,
  'telefono': instance.telefono,
  'email_contacto': instance.emailContacto,
  'estado': instance.estado,
  'created_by': instance.createdBy,
  'stripe_onboarding_status': instance.stripeOnboardingStatus,
  'stripe_charges_enabled': instance.stripeChargesEnabled,
};
