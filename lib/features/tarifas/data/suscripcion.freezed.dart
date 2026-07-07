// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'suscripcion.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$Suscripcion {

 String get id; String get alumnoId; String get tarifaId; String? get tarifaNombre; num? get tarifaPrecio; String? get tarifaPeriodicidad; String get estado; String get paymentStatus; DateTime get fechaInicio;
/// Create a copy of Suscripcion
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SuscripcionCopyWith<Suscripcion> get copyWith => _$SuscripcionCopyWithImpl<Suscripcion>(this as Suscripcion, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Suscripcion&&(identical(other.id, id) || other.id == id)&&(identical(other.alumnoId, alumnoId) || other.alumnoId == alumnoId)&&(identical(other.tarifaId, tarifaId) || other.tarifaId == tarifaId)&&(identical(other.tarifaNombre, tarifaNombre) || other.tarifaNombre == tarifaNombre)&&(identical(other.tarifaPrecio, tarifaPrecio) || other.tarifaPrecio == tarifaPrecio)&&(identical(other.tarifaPeriodicidad, tarifaPeriodicidad) || other.tarifaPeriodicidad == tarifaPeriodicidad)&&(identical(other.estado, estado) || other.estado == estado)&&(identical(other.paymentStatus, paymentStatus) || other.paymentStatus == paymentStatus)&&(identical(other.fechaInicio, fechaInicio) || other.fechaInicio == fechaInicio));
}


@override
int get hashCode => Object.hash(runtimeType,id,alumnoId,tarifaId,tarifaNombre,tarifaPrecio,tarifaPeriodicidad,estado,paymentStatus,fechaInicio);

@override
String toString() {
  return 'Suscripcion(id: $id, alumnoId: $alumnoId, tarifaId: $tarifaId, tarifaNombre: $tarifaNombre, tarifaPrecio: $tarifaPrecio, tarifaPeriodicidad: $tarifaPeriodicidad, estado: $estado, paymentStatus: $paymentStatus, fechaInicio: $fechaInicio)';
}


}

/// @nodoc
abstract mixin class $SuscripcionCopyWith<$Res>  {
  factory $SuscripcionCopyWith(Suscripcion value, $Res Function(Suscripcion) _then) = _$SuscripcionCopyWithImpl;
@useResult
$Res call({
 String id, String alumnoId, String tarifaId, String? tarifaNombre, num? tarifaPrecio, String? tarifaPeriodicidad, String estado, String paymentStatus, DateTime fechaInicio
});




}
/// @nodoc
class _$SuscripcionCopyWithImpl<$Res>
    implements $SuscripcionCopyWith<$Res> {
  _$SuscripcionCopyWithImpl(this._self, this._then);

  final Suscripcion _self;
  final $Res Function(Suscripcion) _then;

/// Create a copy of Suscripcion
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? alumnoId = null,Object? tarifaId = null,Object? tarifaNombre = freezed,Object? tarifaPrecio = freezed,Object? tarifaPeriodicidad = freezed,Object? estado = null,Object? paymentStatus = null,Object? fechaInicio = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,alumnoId: null == alumnoId ? _self.alumnoId : alumnoId // ignore: cast_nullable_to_non_nullable
as String,tarifaId: null == tarifaId ? _self.tarifaId : tarifaId // ignore: cast_nullable_to_non_nullable
as String,tarifaNombre: freezed == tarifaNombre ? _self.tarifaNombre : tarifaNombre // ignore: cast_nullable_to_non_nullable
as String?,tarifaPrecio: freezed == tarifaPrecio ? _self.tarifaPrecio : tarifaPrecio // ignore: cast_nullable_to_non_nullable
as num?,tarifaPeriodicidad: freezed == tarifaPeriodicidad ? _self.tarifaPeriodicidad : tarifaPeriodicidad // ignore: cast_nullable_to_non_nullable
as String?,estado: null == estado ? _self.estado : estado // ignore: cast_nullable_to_non_nullable
as String,paymentStatus: null == paymentStatus ? _self.paymentStatus : paymentStatus // ignore: cast_nullable_to_non_nullable
as String,fechaInicio: null == fechaInicio ? _self.fechaInicio : fechaInicio // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [Suscripcion].
extension SuscripcionPatterns on Suscripcion {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Suscripcion value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Suscripcion() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Suscripcion value)  $default,){
final _that = this;
switch (_that) {
case _Suscripcion():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Suscripcion value)?  $default,){
final _that = this;
switch (_that) {
case _Suscripcion() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String alumnoId,  String tarifaId,  String? tarifaNombre,  num? tarifaPrecio,  String? tarifaPeriodicidad,  String estado,  String paymentStatus,  DateTime fechaInicio)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Suscripcion() when $default != null:
return $default(_that.id,_that.alumnoId,_that.tarifaId,_that.tarifaNombre,_that.tarifaPrecio,_that.tarifaPeriodicidad,_that.estado,_that.paymentStatus,_that.fechaInicio);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String alumnoId,  String tarifaId,  String? tarifaNombre,  num? tarifaPrecio,  String? tarifaPeriodicidad,  String estado,  String paymentStatus,  DateTime fechaInicio)  $default,) {final _that = this;
switch (_that) {
case _Suscripcion():
return $default(_that.id,_that.alumnoId,_that.tarifaId,_that.tarifaNombre,_that.tarifaPrecio,_that.tarifaPeriodicidad,_that.estado,_that.paymentStatus,_that.fechaInicio);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String alumnoId,  String tarifaId,  String? tarifaNombre,  num? tarifaPrecio,  String? tarifaPeriodicidad,  String estado,  String paymentStatus,  DateTime fechaInicio)?  $default,) {final _that = this;
switch (_that) {
case _Suscripcion() when $default != null:
return $default(_that.id,_that.alumnoId,_that.tarifaId,_that.tarifaNombre,_that.tarifaPrecio,_that.tarifaPeriodicidad,_that.estado,_that.paymentStatus,_that.fechaInicio);case _:
  return null;

}
}

}

/// @nodoc


class _Suscripcion implements Suscripcion {
  const _Suscripcion({required this.id, required this.alumnoId, required this.tarifaId, this.tarifaNombre, this.tarifaPrecio, this.tarifaPeriodicidad, required this.estado, required this.paymentStatus, required this.fechaInicio});
  

@override final  String id;
@override final  String alumnoId;
@override final  String tarifaId;
@override final  String? tarifaNombre;
@override final  num? tarifaPrecio;
@override final  String? tarifaPeriodicidad;
@override final  String estado;
@override final  String paymentStatus;
@override final  DateTime fechaInicio;

/// Create a copy of Suscripcion
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SuscripcionCopyWith<_Suscripcion> get copyWith => __$SuscripcionCopyWithImpl<_Suscripcion>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Suscripcion&&(identical(other.id, id) || other.id == id)&&(identical(other.alumnoId, alumnoId) || other.alumnoId == alumnoId)&&(identical(other.tarifaId, tarifaId) || other.tarifaId == tarifaId)&&(identical(other.tarifaNombre, tarifaNombre) || other.tarifaNombre == tarifaNombre)&&(identical(other.tarifaPrecio, tarifaPrecio) || other.tarifaPrecio == tarifaPrecio)&&(identical(other.tarifaPeriodicidad, tarifaPeriodicidad) || other.tarifaPeriodicidad == tarifaPeriodicidad)&&(identical(other.estado, estado) || other.estado == estado)&&(identical(other.paymentStatus, paymentStatus) || other.paymentStatus == paymentStatus)&&(identical(other.fechaInicio, fechaInicio) || other.fechaInicio == fechaInicio));
}


@override
int get hashCode => Object.hash(runtimeType,id,alumnoId,tarifaId,tarifaNombre,tarifaPrecio,tarifaPeriodicidad,estado,paymentStatus,fechaInicio);

@override
String toString() {
  return 'Suscripcion(id: $id, alumnoId: $alumnoId, tarifaId: $tarifaId, tarifaNombre: $tarifaNombre, tarifaPrecio: $tarifaPrecio, tarifaPeriodicidad: $tarifaPeriodicidad, estado: $estado, paymentStatus: $paymentStatus, fechaInicio: $fechaInicio)';
}


}

/// @nodoc
abstract mixin class _$SuscripcionCopyWith<$Res> implements $SuscripcionCopyWith<$Res> {
  factory _$SuscripcionCopyWith(_Suscripcion value, $Res Function(_Suscripcion) _then) = __$SuscripcionCopyWithImpl;
@override @useResult
$Res call({
 String id, String alumnoId, String tarifaId, String? tarifaNombre, num? tarifaPrecio, String? tarifaPeriodicidad, String estado, String paymentStatus, DateTime fechaInicio
});




}
/// @nodoc
class __$SuscripcionCopyWithImpl<$Res>
    implements _$SuscripcionCopyWith<$Res> {
  __$SuscripcionCopyWithImpl(this._self, this._then);

  final _Suscripcion _self;
  final $Res Function(_Suscripcion) _then;

/// Create a copy of Suscripcion
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? alumnoId = null,Object? tarifaId = null,Object? tarifaNombre = freezed,Object? tarifaPrecio = freezed,Object? tarifaPeriodicidad = freezed,Object? estado = null,Object? paymentStatus = null,Object? fechaInicio = null,}) {
  return _then(_Suscripcion(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,alumnoId: null == alumnoId ? _self.alumnoId : alumnoId // ignore: cast_nullable_to_non_nullable
as String,tarifaId: null == tarifaId ? _self.tarifaId : tarifaId // ignore: cast_nullable_to_non_nullable
as String,tarifaNombre: freezed == tarifaNombre ? _self.tarifaNombre : tarifaNombre // ignore: cast_nullable_to_non_nullable
as String?,tarifaPrecio: freezed == tarifaPrecio ? _self.tarifaPrecio : tarifaPrecio // ignore: cast_nullable_to_non_nullable
as num?,tarifaPeriodicidad: freezed == tarifaPeriodicidad ? _self.tarifaPeriodicidad : tarifaPeriodicidad // ignore: cast_nullable_to_non_nullable
as String?,estado: null == estado ? _self.estado : estado // ignore: cast_nullable_to_non_nullable
as String,paymentStatus: null == paymentStatus ? _self.paymentStatus : paymentStatus // ignore: cast_nullable_to_non_nullable
as String,fechaInicio: null == fechaInicio ? _self.fechaInicio : fechaInicio // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

// dart format on
