// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'academia.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Academia {

 String get id; String get nombre; String? get direccion; String? get telefono;@JsonKey(name: 'email_contacto') String? get emailContacto; String get estado;@JsonKey(name: 'created_by') String? get createdBy;@JsonKey(name: 'stripe_onboarding_status') String get stripeOnboardingStatus;@JsonKey(name: 'stripe_charges_enabled') bool get stripeChargesEnabled;
/// Create a copy of Academia
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AcademiaCopyWith<Academia> get copyWith => _$AcademiaCopyWithImpl<Academia>(this as Academia, _$identity);

  /// Serializes this Academia to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Academia&&(identical(other.id, id) || other.id == id)&&(identical(other.nombre, nombre) || other.nombre == nombre)&&(identical(other.direccion, direccion) || other.direccion == direccion)&&(identical(other.telefono, telefono) || other.telefono == telefono)&&(identical(other.emailContacto, emailContacto) || other.emailContacto == emailContacto)&&(identical(other.estado, estado) || other.estado == estado)&&(identical(other.createdBy, createdBy) || other.createdBy == createdBy)&&(identical(other.stripeOnboardingStatus, stripeOnboardingStatus) || other.stripeOnboardingStatus == stripeOnboardingStatus)&&(identical(other.stripeChargesEnabled, stripeChargesEnabled) || other.stripeChargesEnabled == stripeChargesEnabled));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,nombre,direccion,telefono,emailContacto,estado,createdBy,stripeOnboardingStatus,stripeChargesEnabled);

@override
String toString() {
  return 'Academia(id: $id, nombre: $nombre, direccion: $direccion, telefono: $telefono, emailContacto: $emailContacto, estado: $estado, createdBy: $createdBy, stripeOnboardingStatus: $stripeOnboardingStatus, stripeChargesEnabled: $stripeChargesEnabled)';
}


}

/// @nodoc
abstract mixin class $AcademiaCopyWith<$Res>  {
  factory $AcademiaCopyWith(Academia value, $Res Function(Academia) _then) = _$AcademiaCopyWithImpl;
@useResult
$Res call({
 String id, String nombre, String? direccion, String? telefono,@JsonKey(name: 'email_contacto') String? emailContacto, String estado,@JsonKey(name: 'created_by') String? createdBy,@JsonKey(name: 'stripe_onboarding_status') String stripeOnboardingStatus,@JsonKey(name: 'stripe_charges_enabled') bool stripeChargesEnabled
});




}
/// @nodoc
class _$AcademiaCopyWithImpl<$Res>
    implements $AcademiaCopyWith<$Res> {
  _$AcademiaCopyWithImpl(this._self, this._then);

  final Academia _self;
  final $Res Function(Academia) _then;

/// Create a copy of Academia
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? nombre = null,Object? direccion = freezed,Object? telefono = freezed,Object? emailContacto = freezed,Object? estado = null,Object? createdBy = freezed,Object? stripeOnboardingStatus = null,Object? stripeChargesEnabled = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,nombre: null == nombre ? _self.nombre : nombre // ignore: cast_nullable_to_non_nullable
as String,direccion: freezed == direccion ? _self.direccion : direccion // ignore: cast_nullable_to_non_nullable
as String?,telefono: freezed == telefono ? _self.telefono : telefono // ignore: cast_nullable_to_non_nullable
as String?,emailContacto: freezed == emailContacto ? _self.emailContacto : emailContacto // ignore: cast_nullable_to_non_nullable
as String?,estado: null == estado ? _self.estado : estado // ignore: cast_nullable_to_non_nullable
as String,createdBy: freezed == createdBy ? _self.createdBy : createdBy // ignore: cast_nullable_to_non_nullable
as String?,stripeOnboardingStatus: null == stripeOnboardingStatus ? _self.stripeOnboardingStatus : stripeOnboardingStatus // ignore: cast_nullable_to_non_nullable
as String,stripeChargesEnabled: null == stripeChargesEnabled ? _self.stripeChargesEnabled : stripeChargesEnabled // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [Academia].
extension AcademiaPatterns on Academia {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Academia value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Academia() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Academia value)  $default,){
final _that = this;
switch (_that) {
case _Academia():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Academia value)?  $default,){
final _that = this;
switch (_that) {
case _Academia() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String nombre,  String? direccion,  String? telefono, @JsonKey(name: 'email_contacto')  String? emailContacto,  String estado, @JsonKey(name: 'created_by')  String? createdBy, @JsonKey(name: 'stripe_onboarding_status')  String stripeOnboardingStatus, @JsonKey(name: 'stripe_charges_enabled')  bool stripeChargesEnabled)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Academia() when $default != null:
return $default(_that.id,_that.nombre,_that.direccion,_that.telefono,_that.emailContacto,_that.estado,_that.createdBy,_that.stripeOnboardingStatus,_that.stripeChargesEnabled);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String nombre,  String? direccion,  String? telefono, @JsonKey(name: 'email_contacto')  String? emailContacto,  String estado, @JsonKey(name: 'created_by')  String? createdBy, @JsonKey(name: 'stripe_onboarding_status')  String stripeOnboardingStatus, @JsonKey(name: 'stripe_charges_enabled')  bool stripeChargesEnabled)  $default,) {final _that = this;
switch (_that) {
case _Academia():
return $default(_that.id,_that.nombre,_that.direccion,_that.telefono,_that.emailContacto,_that.estado,_that.createdBy,_that.stripeOnboardingStatus,_that.stripeChargesEnabled);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String nombre,  String? direccion,  String? telefono, @JsonKey(name: 'email_contacto')  String? emailContacto,  String estado, @JsonKey(name: 'created_by')  String? createdBy, @JsonKey(name: 'stripe_onboarding_status')  String stripeOnboardingStatus, @JsonKey(name: 'stripe_charges_enabled')  bool stripeChargesEnabled)?  $default,) {final _that = this;
switch (_that) {
case _Academia() when $default != null:
return $default(_that.id,_that.nombre,_that.direccion,_that.telefono,_that.emailContacto,_that.estado,_that.createdBy,_that.stripeOnboardingStatus,_that.stripeChargesEnabled);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Academia extends Academia {
  const _Academia({required this.id, required this.nombre, this.direccion, this.telefono, @JsonKey(name: 'email_contacto') this.emailContacto, required this.estado, @JsonKey(name: 'created_by') this.createdBy, @JsonKey(name: 'stripe_onboarding_status') this.stripeOnboardingStatus = 'not_started', @JsonKey(name: 'stripe_charges_enabled') this.stripeChargesEnabled = false}): super._();
  factory _Academia.fromJson(Map<String, dynamic> json) => _$AcademiaFromJson(json);

@override final  String id;
@override final  String nombre;
@override final  String? direccion;
@override final  String? telefono;
@override@JsonKey(name: 'email_contacto') final  String? emailContacto;
@override final  String estado;
@override@JsonKey(name: 'created_by') final  String? createdBy;
@override@JsonKey(name: 'stripe_onboarding_status') final  String stripeOnboardingStatus;
@override@JsonKey(name: 'stripe_charges_enabled') final  bool stripeChargesEnabled;

/// Create a copy of Academia
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AcademiaCopyWith<_Academia> get copyWith => __$AcademiaCopyWithImpl<_Academia>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AcademiaToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Academia&&(identical(other.id, id) || other.id == id)&&(identical(other.nombre, nombre) || other.nombre == nombre)&&(identical(other.direccion, direccion) || other.direccion == direccion)&&(identical(other.telefono, telefono) || other.telefono == telefono)&&(identical(other.emailContacto, emailContacto) || other.emailContacto == emailContacto)&&(identical(other.estado, estado) || other.estado == estado)&&(identical(other.createdBy, createdBy) || other.createdBy == createdBy)&&(identical(other.stripeOnboardingStatus, stripeOnboardingStatus) || other.stripeOnboardingStatus == stripeOnboardingStatus)&&(identical(other.stripeChargesEnabled, stripeChargesEnabled) || other.stripeChargesEnabled == stripeChargesEnabled));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,nombre,direccion,telefono,emailContacto,estado,createdBy,stripeOnboardingStatus,stripeChargesEnabled);

@override
String toString() {
  return 'Academia(id: $id, nombre: $nombre, direccion: $direccion, telefono: $telefono, emailContacto: $emailContacto, estado: $estado, createdBy: $createdBy, stripeOnboardingStatus: $stripeOnboardingStatus, stripeChargesEnabled: $stripeChargesEnabled)';
}


}

/// @nodoc
abstract mixin class _$AcademiaCopyWith<$Res> implements $AcademiaCopyWith<$Res> {
  factory _$AcademiaCopyWith(_Academia value, $Res Function(_Academia) _then) = __$AcademiaCopyWithImpl;
@override @useResult
$Res call({
 String id, String nombre, String? direccion, String? telefono,@JsonKey(name: 'email_contacto') String? emailContacto, String estado,@JsonKey(name: 'created_by') String? createdBy,@JsonKey(name: 'stripe_onboarding_status') String stripeOnboardingStatus,@JsonKey(name: 'stripe_charges_enabled') bool stripeChargesEnabled
});




}
/// @nodoc
class __$AcademiaCopyWithImpl<$Res>
    implements _$AcademiaCopyWith<$Res> {
  __$AcademiaCopyWithImpl(this._self, this._then);

  final _Academia _self;
  final $Res Function(_Academia) _then;

/// Create a copy of Academia
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? nombre = null,Object? direccion = freezed,Object? telefono = freezed,Object? emailContacto = freezed,Object? estado = null,Object? createdBy = freezed,Object? stripeOnboardingStatus = null,Object? stripeChargesEnabled = null,}) {
  return _then(_Academia(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,nombre: null == nombre ? _self.nombre : nombre // ignore: cast_nullable_to_non_nullable
as String,direccion: freezed == direccion ? _self.direccion : direccion // ignore: cast_nullable_to_non_nullable
as String?,telefono: freezed == telefono ? _self.telefono : telefono // ignore: cast_nullable_to_non_nullable
as String?,emailContacto: freezed == emailContacto ? _self.emailContacto : emailContacto // ignore: cast_nullable_to_non_nullable
as String?,estado: null == estado ? _self.estado : estado // ignore: cast_nullable_to_non_nullable
as String,createdBy: freezed == createdBy ? _self.createdBy : createdBy // ignore: cast_nullable_to_non_nullable
as String?,stripeOnboardingStatus: null == stripeOnboardingStatus ? _self.stripeOnboardingStatus : stripeOnboardingStatus // ignore: cast_nullable_to_non_nullable
as String,stripeChargesEnabled: null == stripeChargesEnabled ? _self.stripeChargesEnabled : stripeChargesEnabled // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
