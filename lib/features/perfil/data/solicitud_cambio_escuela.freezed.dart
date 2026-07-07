// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'solicitud_cambio_escuela.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$MiSolicitudCambio {

 String get id; String get estado; String get academiaDestinoId; String get academiaDestinoNombre; DateTime get createdAt;
/// Create a copy of MiSolicitudCambio
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MiSolicitudCambioCopyWith<MiSolicitudCambio> get copyWith => _$MiSolicitudCambioCopyWithImpl<MiSolicitudCambio>(this as MiSolicitudCambio, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MiSolicitudCambio&&(identical(other.id, id) || other.id == id)&&(identical(other.estado, estado) || other.estado == estado)&&(identical(other.academiaDestinoId, academiaDestinoId) || other.academiaDestinoId == academiaDestinoId)&&(identical(other.academiaDestinoNombre, academiaDestinoNombre) || other.academiaDestinoNombre == academiaDestinoNombre)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}


@override
int get hashCode => Object.hash(runtimeType,id,estado,academiaDestinoId,academiaDestinoNombre,createdAt);

@override
String toString() {
  return 'MiSolicitudCambio(id: $id, estado: $estado, academiaDestinoId: $academiaDestinoId, academiaDestinoNombre: $academiaDestinoNombre, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class $MiSolicitudCambioCopyWith<$Res>  {
  factory $MiSolicitudCambioCopyWith(MiSolicitudCambio value, $Res Function(MiSolicitudCambio) _then) = _$MiSolicitudCambioCopyWithImpl;
@useResult
$Res call({
 String id, String estado, String academiaDestinoId, String academiaDestinoNombre, DateTime createdAt
});




}
/// @nodoc
class _$MiSolicitudCambioCopyWithImpl<$Res>
    implements $MiSolicitudCambioCopyWith<$Res> {
  _$MiSolicitudCambioCopyWithImpl(this._self, this._then);

  final MiSolicitudCambio _self;
  final $Res Function(MiSolicitudCambio) _then;

/// Create a copy of MiSolicitudCambio
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? estado = null,Object? academiaDestinoId = null,Object? academiaDestinoNombre = null,Object? createdAt = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,estado: null == estado ? _self.estado : estado // ignore: cast_nullable_to_non_nullable
as String,academiaDestinoId: null == academiaDestinoId ? _self.academiaDestinoId : academiaDestinoId // ignore: cast_nullable_to_non_nullable
as String,academiaDestinoNombre: null == academiaDestinoNombre ? _self.academiaDestinoNombre : academiaDestinoNombre // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [MiSolicitudCambio].
extension MiSolicitudCambioPatterns on MiSolicitudCambio {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MiSolicitudCambio value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MiSolicitudCambio() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MiSolicitudCambio value)  $default,){
final _that = this;
switch (_that) {
case _MiSolicitudCambio():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MiSolicitudCambio value)?  $default,){
final _that = this;
switch (_that) {
case _MiSolicitudCambio() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String estado,  String academiaDestinoId,  String academiaDestinoNombre,  DateTime createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MiSolicitudCambio() when $default != null:
return $default(_that.id,_that.estado,_that.academiaDestinoId,_that.academiaDestinoNombre,_that.createdAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String estado,  String academiaDestinoId,  String academiaDestinoNombre,  DateTime createdAt)  $default,) {final _that = this;
switch (_that) {
case _MiSolicitudCambio():
return $default(_that.id,_that.estado,_that.academiaDestinoId,_that.academiaDestinoNombre,_that.createdAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String estado,  String academiaDestinoId,  String academiaDestinoNombre,  DateTime createdAt)?  $default,) {final _that = this;
switch (_that) {
case _MiSolicitudCambio() when $default != null:
return $default(_that.id,_that.estado,_that.academiaDestinoId,_that.academiaDestinoNombre,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc


class _MiSolicitudCambio implements MiSolicitudCambio {
  const _MiSolicitudCambio({required this.id, required this.estado, required this.academiaDestinoId, required this.academiaDestinoNombre, required this.createdAt});
  

@override final  String id;
@override final  String estado;
@override final  String academiaDestinoId;
@override final  String academiaDestinoNombre;
@override final  DateTime createdAt;

/// Create a copy of MiSolicitudCambio
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MiSolicitudCambioCopyWith<_MiSolicitudCambio> get copyWith => __$MiSolicitudCambioCopyWithImpl<_MiSolicitudCambio>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MiSolicitudCambio&&(identical(other.id, id) || other.id == id)&&(identical(other.estado, estado) || other.estado == estado)&&(identical(other.academiaDestinoId, academiaDestinoId) || other.academiaDestinoId == academiaDestinoId)&&(identical(other.academiaDestinoNombre, academiaDestinoNombre) || other.academiaDestinoNombre == academiaDestinoNombre)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}


@override
int get hashCode => Object.hash(runtimeType,id,estado,academiaDestinoId,academiaDestinoNombre,createdAt);

@override
String toString() {
  return 'MiSolicitudCambio(id: $id, estado: $estado, academiaDestinoId: $academiaDestinoId, academiaDestinoNombre: $academiaDestinoNombre, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$MiSolicitudCambioCopyWith<$Res> implements $MiSolicitudCambioCopyWith<$Res> {
  factory _$MiSolicitudCambioCopyWith(_MiSolicitudCambio value, $Res Function(_MiSolicitudCambio) _then) = __$MiSolicitudCambioCopyWithImpl;
@override @useResult
$Res call({
 String id, String estado, String academiaDestinoId, String academiaDestinoNombre, DateTime createdAt
});




}
/// @nodoc
class __$MiSolicitudCambioCopyWithImpl<$Res>
    implements _$MiSolicitudCambioCopyWith<$Res> {
  __$MiSolicitudCambioCopyWithImpl(this._self, this._then);

  final _MiSolicitudCambio _self;
  final $Res Function(_MiSolicitudCambio) _then;

/// Create a copy of MiSolicitudCambio
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? estado = null,Object? academiaDestinoId = null,Object? academiaDestinoNombre = null,Object? createdAt = null,}) {
  return _then(_MiSolicitudCambio(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,estado: null == estado ? _self.estado : estado // ignore: cast_nullable_to_non_nullable
as String,academiaDestinoId: null == academiaDestinoId ? _self.academiaDestinoId : academiaDestinoId // ignore: cast_nullable_to_non_nullable
as String,academiaDestinoNombre: null == academiaDestinoNombre ? _self.academiaDestinoNombre : academiaDestinoNombre // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

/// @nodoc
mixin _$SolicitudPendiente {

 String get id; String get alumnoId; String get alumnoNombre; String get academiaOrigenId; String get academiaOrigenNombre; DateTime get createdAt;
/// Create a copy of SolicitudPendiente
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SolicitudPendienteCopyWith<SolicitudPendiente> get copyWith => _$SolicitudPendienteCopyWithImpl<SolicitudPendiente>(this as SolicitudPendiente, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SolicitudPendiente&&(identical(other.id, id) || other.id == id)&&(identical(other.alumnoId, alumnoId) || other.alumnoId == alumnoId)&&(identical(other.alumnoNombre, alumnoNombre) || other.alumnoNombre == alumnoNombre)&&(identical(other.academiaOrigenId, academiaOrigenId) || other.academiaOrigenId == academiaOrigenId)&&(identical(other.academiaOrigenNombre, academiaOrigenNombre) || other.academiaOrigenNombre == academiaOrigenNombre)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}


@override
int get hashCode => Object.hash(runtimeType,id,alumnoId,alumnoNombre,academiaOrigenId,academiaOrigenNombre,createdAt);

@override
String toString() {
  return 'SolicitudPendiente(id: $id, alumnoId: $alumnoId, alumnoNombre: $alumnoNombre, academiaOrigenId: $academiaOrigenId, academiaOrigenNombre: $academiaOrigenNombre, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class $SolicitudPendienteCopyWith<$Res>  {
  factory $SolicitudPendienteCopyWith(SolicitudPendiente value, $Res Function(SolicitudPendiente) _then) = _$SolicitudPendienteCopyWithImpl;
@useResult
$Res call({
 String id, String alumnoId, String alumnoNombre, String academiaOrigenId, String academiaOrigenNombre, DateTime createdAt
});




}
/// @nodoc
class _$SolicitudPendienteCopyWithImpl<$Res>
    implements $SolicitudPendienteCopyWith<$Res> {
  _$SolicitudPendienteCopyWithImpl(this._self, this._then);

  final SolicitudPendiente _self;
  final $Res Function(SolicitudPendiente) _then;

/// Create a copy of SolicitudPendiente
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? alumnoId = null,Object? alumnoNombre = null,Object? academiaOrigenId = null,Object? academiaOrigenNombre = null,Object? createdAt = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,alumnoId: null == alumnoId ? _self.alumnoId : alumnoId // ignore: cast_nullable_to_non_nullable
as String,alumnoNombre: null == alumnoNombre ? _self.alumnoNombre : alumnoNombre // ignore: cast_nullable_to_non_nullable
as String,academiaOrigenId: null == academiaOrigenId ? _self.academiaOrigenId : academiaOrigenId // ignore: cast_nullable_to_non_nullable
as String,academiaOrigenNombre: null == academiaOrigenNombre ? _self.academiaOrigenNombre : academiaOrigenNombre // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [SolicitudPendiente].
extension SolicitudPendientePatterns on SolicitudPendiente {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SolicitudPendiente value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SolicitudPendiente() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SolicitudPendiente value)  $default,){
final _that = this;
switch (_that) {
case _SolicitudPendiente():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SolicitudPendiente value)?  $default,){
final _that = this;
switch (_that) {
case _SolicitudPendiente() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String alumnoId,  String alumnoNombre,  String academiaOrigenId,  String academiaOrigenNombre,  DateTime createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SolicitudPendiente() when $default != null:
return $default(_that.id,_that.alumnoId,_that.alumnoNombre,_that.academiaOrigenId,_that.academiaOrigenNombre,_that.createdAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String alumnoId,  String alumnoNombre,  String academiaOrigenId,  String academiaOrigenNombre,  DateTime createdAt)  $default,) {final _that = this;
switch (_that) {
case _SolicitudPendiente():
return $default(_that.id,_that.alumnoId,_that.alumnoNombre,_that.academiaOrigenId,_that.academiaOrigenNombre,_that.createdAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String alumnoId,  String alumnoNombre,  String academiaOrigenId,  String academiaOrigenNombre,  DateTime createdAt)?  $default,) {final _that = this;
switch (_that) {
case _SolicitudPendiente() when $default != null:
return $default(_that.id,_that.alumnoId,_that.alumnoNombre,_that.academiaOrigenId,_that.academiaOrigenNombre,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc


class _SolicitudPendiente implements SolicitudPendiente {
  const _SolicitudPendiente({required this.id, required this.alumnoId, required this.alumnoNombre, required this.academiaOrigenId, required this.academiaOrigenNombre, required this.createdAt});
  

@override final  String id;
@override final  String alumnoId;
@override final  String alumnoNombre;
@override final  String academiaOrigenId;
@override final  String academiaOrigenNombre;
@override final  DateTime createdAt;

/// Create a copy of SolicitudPendiente
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SolicitudPendienteCopyWith<_SolicitudPendiente> get copyWith => __$SolicitudPendienteCopyWithImpl<_SolicitudPendiente>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SolicitudPendiente&&(identical(other.id, id) || other.id == id)&&(identical(other.alumnoId, alumnoId) || other.alumnoId == alumnoId)&&(identical(other.alumnoNombre, alumnoNombre) || other.alumnoNombre == alumnoNombre)&&(identical(other.academiaOrigenId, academiaOrigenId) || other.academiaOrigenId == academiaOrigenId)&&(identical(other.academiaOrigenNombre, academiaOrigenNombre) || other.academiaOrigenNombre == academiaOrigenNombre)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}


@override
int get hashCode => Object.hash(runtimeType,id,alumnoId,alumnoNombre,academiaOrigenId,academiaOrigenNombre,createdAt);

@override
String toString() {
  return 'SolicitudPendiente(id: $id, alumnoId: $alumnoId, alumnoNombre: $alumnoNombre, academiaOrigenId: $academiaOrigenId, academiaOrigenNombre: $academiaOrigenNombre, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$SolicitudPendienteCopyWith<$Res> implements $SolicitudPendienteCopyWith<$Res> {
  factory _$SolicitudPendienteCopyWith(_SolicitudPendiente value, $Res Function(_SolicitudPendiente) _then) = __$SolicitudPendienteCopyWithImpl;
@override @useResult
$Res call({
 String id, String alumnoId, String alumnoNombre, String academiaOrigenId, String academiaOrigenNombre, DateTime createdAt
});




}
/// @nodoc
class __$SolicitudPendienteCopyWithImpl<$Res>
    implements _$SolicitudPendienteCopyWith<$Res> {
  __$SolicitudPendienteCopyWithImpl(this._self, this._then);

  final _SolicitudPendiente _self;
  final $Res Function(_SolicitudPendiente) _then;

/// Create a copy of SolicitudPendiente
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? alumnoId = null,Object? alumnoNombre = null,Object? academiaOrigenId = null,Object? academiaOrigenNombre = null,Object? createdAt = null,}) {
  return _then(_SolicitudPendiente(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,alumnoId: null == alumnoId ? _self.alumnoId : alumnoId // ignore: cast_nullable_to_non_nullable
as String,alumnoNombre: null == alumnoNombre ? _self.alumnoNombre : alumnoNombre // ignore: cast_nullable_to_non_nullable
as String,academiaOrigenId: null == academiaOrigenId ? _self.academiaOrigenId : academiaOrigenId // ignore: cast_nullable_to_non_nullable
as String,academiaOrigenNombre: null == academiaOrigenNombre ? _self.academiaOrigenNombre : academiaOrigenNombre // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

// dart format on
