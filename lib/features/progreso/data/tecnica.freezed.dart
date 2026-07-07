// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'tecnica.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Tecnica {

 String get id;@JsonKey(name: 'academia_id') String get academiaId; String get cinturon; String get nombre; String? get descripcion; int get orden;
/// Create a copy of Tecnica
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TecnicaCopyWith<Tecnica> get copyWith => _$TecnicaCopyWithImpl<Tecnica>(this as Tecnica, _$identity);

  /// Serializes this Tecnica to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Tecnica&&(identical(other.id, id) || other.id == id)&&(identical(other.academiaId, academiaId) || other.academiaId == academiaId)&&(identical(other.cinturon, cinturon) || other.cinturon == cinturon)&&(identical(other.nombre, nombre) || other.nombre == nombre)&&(identical(other.descripcion, descripcion) || other.descripcion == descripcion)&&(identical(other.orden, orden) || other.orden == orden));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,academiaId,cinturon,nombre,descripcion,orden);

@override
String toString() {
  return 'Tecnica(id: $id, academiaId: $academiaId, cinturon: $cinturon, nombre: $nombre, descripcion: $descripcion, orden: $orden)';
}


}

/// @nodoc
abstract mixin class $TecnicaCopyWith<$Res>  {
  factory $TecnicaCopyWith(Tecnica value, $Res Function(Tecnica) _then) = _$TecnicaCopyWithImpl;
@useResult
$Res call({
 String id,@JsonKey(name: 'academia_id') String academiaId, String cinturon, String nombre, String? descripcion, int orden
});




}
/// @nodoc
class _$TecnicaCopyWithImpl<$Res>
    implements $TecnicaCopyWith<$Res> {
  _$TecnicaCopyWithImpl(this._self, this._then);

  final Tecnica _self;
  final $Res Function(Tecnica) _then;

/// Create a copy of Tecnica
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? academiaId = null,Object? cinturon = null,Object? nombre = null,Object? descripcion = freezed,Object? orden = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,academiaId: null == academiaId ? _self.academiaId : academiaId // ignore: cast_nullable_to_non_nullable
as String,cinturon: null == cinturon ? _self.cinturon : cinturon // ignore: cast_nullable_to_non_nullable
as String,nombre: null == nombre ? _self.nombre : nombre // ignore: cast_nullable_to_non_nullable
as String,descripcion: freezed == descripcion ? _self.descripcion : descripcion // ignore: cast_nullable_to_non_nullable
as String?,orden: null == orden ? _self.orden : orden // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [Tecnica].
extension TecnicaPatterns on Tecnica {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Tecnica value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Tecnica() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Tecnica value)  $default,){
final _that = this;
switch (_that) {
case _Tecnica():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Tecnica value)?  $default,){
final _that = this;
switch (_that) {
case _Tecnica() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'academia_id')  String academiaId,  String cinturon,  String nombre,  String? descripcion,  int orden)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Tecnica() when $default != null:
return $default(_that.id,_that.academiaId,_that.cinturon,_that.nombre,_that.descripcion,_that.orden);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'academia_id')  String academiaId,  String cinturon,  String nombre,  String? descripcion,  int orden)  $default,) {final _that = this;
switch (_that) {
case _Tecnica():
return $default(_that.id,_that.academiaId,_that.cinturon,_that.nombre,_that.descripcion,_that.orden);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id, @JsonKey(name: 'academia_id')  String academiaId,  String cinturon,  String nombre,  String? descripcion,  int orden)?  $default,) {final _that = this;
switch (_that) {
case _Tecnica() when $default != null:
return $default(_that.id,_that.academiaId,_that.cinturon,_that.nombre,_that.descripcion,_that.orden);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Tecnica implements Tecnica {
  const _Tecnica({required this.id, @JsonKey(name: 'academia_id') required this.academiaId, required this.cinturon, required this.nombre, this.descripcion, required this.orden});
  factory _Tecnica.fromJson(Map<String, dynamic> json) => _$TecnicaFromJson(json);

@override final  String id;
@override@JsonKey(name: 'academia_id') final  String academiaId;
@override final  String cinturon;
@override final  String nombre;
@override final  String? descripcion;
@override final  int orden;

/// Create a copy of Tecnica
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TecnicaCopyWith<_Tecnica> get copyWith => __$TecnicaCopyWithImpl<_Tecnica>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TecnicaToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Tecnica&&(identical(other.id, id) || other.id == id)&&(identical(other.academiaId, academiaId) || other.academiaId == academiaId)&&(identical(other.cinturon, cinturon) || other.cinturon == cinturon)&&(identical(other.nombre, nombre) || other.nombre == nombre)&&(identical(other.descripcion, descripcion) || other.descripcion == descripcion)&&(identical(other.orden, orden) || other.orden == orden));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,academiaId,cinturon,nombre,descripcion,orden);

@override
String toString() {
  return 'Tecnica(id: $id, academiaId: $academiaId, cinturon: $cinturon, nombre: $nombre, descripcion: $descripcion, orden: $orden)';
}


}

/// @nodoc
abstract mixin class _$TecnicaCopyWith<$Res> implements $TecnicaCopyWith<$Res> {
  factory _$TecnicaCopyWith(_Tecnica value, $Res Function(_Tecnica) _then) = __$TecnicaCopyWithImpl;
@override @useResult
$Res call({
 String id,@JsonKey(name: 'academia_id') String academiaId, String cinturon, String nombre, String? descripcion, int orden
});




}
/// @nodoc
class __$TecnicaCopyWithImpl<$Res>
    implements _$TecnicaCopyWith<$Res> {
  __$TecnicaCopyWithImpl(this._self, this._then);

  final _Tecnica _self;
  final $Res Function(_Tecnica) _then;

/// Create a copy of Tecnica
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? academiaId = null,Object? cinturon = null,Object? nombre = null,Object? descripcion = freezed,Object? orden = null,}) {
  return _then(_Tecnica(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,academiaId: null == academiaId ? _self.academiaId : academiaId // ignore: cast_nullable_to_non_nullable
as String,cinturon: null == cinturon ? _self.cinturon : cinturon // ignore: cast_nullable_to_non_nullable
as String,nombre: null == nombre ? _self.nombre : nombre // ignore: cast_nullable_to_non_nullable
as String,descripcion: freezed == descripcion ? _self.descripcion : descripcion // ignore: cast_nullable_to_non_nullable
as String?,orden: null == orden ? _self.orden : orden // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
