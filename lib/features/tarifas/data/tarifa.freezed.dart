// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'tarifa.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Tarifa {

 String get id;@JsonKey(name: 'academia_id') String get academiaId; String get nombre; String? get descripcion; num get precio; String get periodicidad; bool get activo;
/// Create a copy of Tarifa
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TarifaCopyWith<Tarifa> get copyWith => _$TarifaCopyWithImpl<Tarifa>(this as Tarifa, _$identity);

  /// Serializes this Tarifa to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Tarifa&&(identical(other.id, id) || other.id == id)&&(identical(other.academiaId, academiaId) || other.academiaId == academiaId)&&(identical(other.nombre, nombre) || other.nombre == nombre)&&(identical(other.descripcion, descripcion) || other.descripcion == descripcion)&&(identical(other.precio, precio) || other.precio == precio)&&(identical(other.periodicidad, periodicidad) || other.periodicidad == periodicidad)&&(identical(other.activo, activo) || other.activo == activo));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,academiaId,nombre,descripcion,precio,periodicidad,activo);

@override
String toString() {
  return 'Tarifa(id: $id, academiaId: $academiaId, nombre: $nombre, descripcion: $descripcion, precio: $precio, periodicidad: $periodicidad, activo: $activo)';
}


}

/// @nodoc
abstract mixin class $TarifaCopyWith<$Res>  {
  factory $TarifaCopyWith(Tarifa value, $Res Function(Tarifa) _then) = _$TarifaCopyWithImpl;
@useResult
$Res call({
 String id,@JsonKey(name: 'academia_id') String academiaId, String nombre, String? descripcion, num precio, String periodicidad, bool activo
});




}
/// @nodoc
class _$TarifaCopyWithImpl<$Res>
    implements $TarifaCopyWith<$Res> {
  _$TarifaCopyWithImpl(this._self, this._then);

  final Tarifa _self;
  final $Res Function(Tarifa) _then;

/// Create a copy of Tarifa
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? academiaId = null,Object? nombre = null,Object? descripcion = freezed,Object? precio = null,Object? periodicidad = null,Object? activo = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,academiaId: null == academiaId ? _self.academiaId : academiaId // ignore: cast_nullable_to_non_nullable
as String,nombre: null == nombre ? _self.nombre : nombre // ignore: cast_nullable_to_non_nullable
as String,descripcion: freezed == descripcion ? _self.descripcion : descripcion // ignore: cast_nullable_to_non_nullable
as String?,precio: null == precio ? _self.precio : precio // ignore: cast_nullable_to_non_nullable
as num,periodicidad: null == periodicidad ? _self.periodicidad : periodicidad // ignore: cast_nullable_to_non_nullable
as String,activo: null == activo ? _self.activo : activo // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [Tarifa].
extension TarifaPatterns on Tarifa {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Tarifa value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Tarifa() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Tarifa value)  $default,){
final _that = this;
switch (_that) {
case _Tarifa():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Tarifa value)?  $default,){
final _that = this;
switch (_that) {
case _Tarifa() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'academia_id')  String academiaId,  String nombre,  String? descripcion,  num precio,  String periodicidad,  bool activo)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Tarifa() when $default != null:
return $default(_that.id,_that.academiaId,_that.nombre,_that.descripcion,_that.precio,_that.periodicidad,_that.activo);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'academia_id')  String academiaId,  String nombre,  String? descripcion,  num precio,  String periodicidad,  bool activo)  $default,) {final _that = this;
switch (_that) {
case _Tarifa():
return $default(_that.id,_that.academiaId,_that.nombre,_that.descripcion,_that.precio,_that.periodicidad,_that.activo);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id, @JsonKey(name: 'academia_id')  String academiaId,  String nombre,  String? descripcion,  num precio,  String periodicidad,  bool activo)?  $default,) {final _that = this;
switch (_that) {
case _Tarifa() when $default != null:
return $default(_that.id,_that.academiaId,_that.nombre,_that.descripcion,_that.precio,_that.periodicidad,_that.activo);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Tarifa implements Tarifa {
  const _Tarifa({required this.id, @JsonKey(name: 'academia_id') required this.academiaId, required this.nombre, this.descripcion, required this.precio, required this.periodicidad, required this.activo});
  factory _Tarifa.fromJson(Map<String, dynamic> json) => _$TarifaFromJson(json);

@override final  String id;
@override@JsonKey(name: 'academia_id') final  String academiaId;
@override final  String nombre;
@override final  String? descripcion;
@override final  num precio;
@override final  String periodicidad;
@override final  bool activo;

/// Create a copy of Tarifa
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TarifaCopyWith<_Tarifa> get copyWith => __$TarifaCopyWithImpl<_Tarifa>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TarifaToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Tarifa&&(identical(other.id, id) || other.id == id)&&(identical(other.academiaId, academiaId) || other.academiaId == academiaId)&&(identical(other.nombre, nombre) || other.nombre == nombre)&&(identical(other.descripcion, descripcion) || other.descripcion == descripcion)&&(identical(other.precio, precio) || other.precio == precio)&&(identical(other.periodicidad, periodicidad) || other.periodicidad == periodicidad)&&(identical(other.activo, activo) || other.activo == activo));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,academiaId,nombre,descripcion,precio,periodicidad,activo);

@override
String toString() {
  return 'Tarifa(id: $id, academiaId: $academiaId, nombre: $nombre, descripcion: $descripcion, precio: $precio, periodicidad: $periodicidad, activo: $activo)';
}


}

/// @nodoc
abstract mixin class _$TarifaCopyWith<$Res> implements $TarifaCopyWith<$Res> {
  factory _$TarifaCopyWith(_Tarifa value, $Res Function(_Tarifa) _then) = __$TarifaCopyWithImpl;
@override @useResult
$Res call({
 String id,@JsonKey(name: 'academia_id') String academiaId, String nombre, String? descripcion, num precio, String periodicidad, bool activo
});




}
/// @nodoc
class __$TarifaCopyWithImpl<$Res>
    implements _$TarifaCopyWith<$Res> {
  __$TarifaCopyWithImpl(this._self, this._then);

  final _Tarifa _self;
  final $Res Function(_Tarifa) _then;

/// Create a copy of Tarifa
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? academiaId = null,Object? nombre = null,Object? descripcion = freezed,Object? precio = null,Object? periodicidad = null,Object? activo = null,}) {
  return _then(_Tarifa(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,academiaId: null == academiaId ? _self.academiaId : academiaId // ignore: cast_nullable_to_non_nullable
as String,nombre: null == nombre ? _self.nombre : nombre // ignore: cast_nullable_to_non_nullable
as String,descripcion: freezed == descripcion ? _self.descripcion : descripcion // ignore: cast_nullable_to_non_nullable
as String?,precio: null == precio ? _self.precio : precio // ignore: cast_nullable_to_non_nullable
as num,periodicidad: null == periodicidad ? _self.periodicidad : periodicidad // ignore: cast_nullable_to_non_nullable
as String,activo: null == activo ? _self.activo : activo // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
