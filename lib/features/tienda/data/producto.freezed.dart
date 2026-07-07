// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'producto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Producto {

 String get id;@JsonKey(name: 'academia_id') String get academiaId; String get nombre; String? get descripcion; num get precio; int get stock;@JsonKey(name: 'foto_url') String? get fotoUrl; bool get activo;
/// Create a copy of Producto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProductoCopyWith<Producto> get copyWith => _$ProductoCopyWithImpl<Producto>(this as Producto, _$identity);

  /// Serializes this Producto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Producto&&(identical(other.id, id) || other.id == id)&&(identical(other.academiaId, academiaId) || other.academiaId == academiaId)&&(identical(other.nombre, nombre) || other.nombre == nombre)&&(identical(other.descripcion, descripcion) || other.descripcion == descripcion)&&(identical(other.precio, precio) || other.precio == precio)&&(identical(other.stock, stock) || other.stock == stock)&&(identical(other.fotoUrl, fotoUrl) || other.fotoUrl == fotoUrl)&&(identical(other.activo, activo) || other.activo == activo));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,academiaId,nombre,descripcion,precio,stock,fotoUrl,activo);

@override
String toString() {
  return 'Producto(id: $id, academiaId: $academiaId, nombre: $nombre, descripcion: $descripcion, precio: $precio, stock: $stock, fotoUrl: $fotoUrl, activo: $activo)';
}


}

/// @nodoc
abstract mixin class $ProductoCopyWith<$Res>  {
  factory $ProductoCopyWith(Producto value, $Res Function(Producto) _then) = _$ProductoCopyWithImpl;
@useResult
$Res call({
 String id,@JsonKey(name: 'academia_id') String academiaId, String nombre, String? descripcion, num precio, int stock,@JsonKey(name: 'foto_url') String? fotoUrl, bool activo
});




}
/// @nodoc
class _$ProductoCopyWithImpl<$Res>
    implements $ProductoCopyWith<$Res> {
  _$ProductoCopyWithImpl(this._self, this._then);

  final Producto _self;
  final $Res Function(Producto) _then;

/// Create a copy of Producto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? academiaId = null,Object? nombre = null,Object? descripcion = freezed,Object? precio = null,Object? stock = null,Object? fotoUrl = freezed,Object? activo = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,academiaId: null == academiaId ? _self.academiaId : academiaId // ignore: cast_nullable_to_non_nullable
as String,nombre: null == nombre ? _self.nombre : nombre // ignore: cast_nullable_to_non_nullable
as String,descripcion: freezed == descripcion ? _self.descripcion : descripcion // ignore: cast_nullable_to_non_nullable
as String?,precio: null == precio ? _self.precio : precio // ignore: cast_nullable_to_non_nullable
as num,stock: null == stock ? _self.stock : stock // ignore: cast_nullable_to_non_nullable
as int,fotoUrl: freezed == fotoUrl ? _self.fotoUrl : fotoUrl // ignore: cast_nullable_to_non_nullable
as String?,activo: null == activo ? _self.activo : activo // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [Producto].
extension ProductoPatterns on Producto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Producto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Producto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Producto value)  $default,){
final _that = this;
switch (_that) {
case _Producto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Producto value)?  $default,){
final _that = this;
switch (_that) {
case _Producto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'academia_id')  String academiaId,  String nombre,  String? descripcion,  num precio,  int stock, @JsonKey(name: 'foto_url')  String? fotoUrl,  bool activo)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Producto() when $default != null:
return $default(_that.id,_that.academiaId,_that.nombre,_that.descripcion,_that.precio,_that.stock,_that.fotoUrl,_that.activo);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'academia_id')  String academiaId,  String nombre,  String? descripcion,  num precio,  int stock, @JsonKey(name: 'foto_url')  String? fotoUrl,  bool activo)  $default,) {final _that = this;
switch (_that) {
case _Producto():
return $default(_that.id,_that.academiaId,_that.nombre,_that.descripcion,_that.precio,_that.stock,_that.fotoUrl,_that.activo);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id, @JsonKey(name: 'academia_id')  String academiaId,  String nombre,  String? descripcion,  num precio,  int stock, @JsonKey(name: 'foto_url')  String? fotoUrl,  bool activo)?  $default,) {final _that = this;
switch (_that) {
case _Producto() when $default != null:
return $default(_that.id,_that.academiaId,_that.nombre,_that.descripcion,_that.precio,_that.stock,_that.fotoUrl,_that.activo);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Producto implements Producto {
  const _Producto({required this.id, @JsonKey(name: 'academia_id') required this.academiaId, required this.nombre, this.descripcion, required this.precio, required this.stock, @JsonKey(name: 'foto_url') this.fotoUrl, required this.activo});
  factory _Producto.fromJson(Map<String, dynamic> json) => _$ProductoFromJson(json);

@override final  String id;
@override@JsonKey(name: 'academia_id') final  String academiaId;
@override final  String nombre;
@override final  String? descripcion;
@override final  num precio;
@override final  int stock;
@override@JsonKey(name: 'foto_url') final  String? fotoUrl;
@override final  bool activo;

/// Create a copy of Producto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProductoCopyWith<_Producto> get copyWith => __$ProductoCopyWithImpl<_Producto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ProductoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Producto&&(identical(other.id, id) || other.id == id)&&(identical(other.academiaId, academiaId) || other.academiaId == academiaId)&&(identical(other.nombre, nombre) || other.nombre == nombre)&&(identical(other.descripcion, descripcion) || other.descripcion == descripcion)&&(identical(other.precio, precio) || other.precio == precio)&&(identical(other.stock, stock) || other.stock == stock)&&(identical(other.fotoUrl, fotoUrl) || other.fotoUrl == fotoUrl)&&(identical(other.activo, activo) || other.activo == activo));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,academiaId,nombre,descripcion,precio,stock,fotoUrl,activo);

@override
String toString() {
  return 'Producto(id: $id, academiaId: $academiaId, nombre: $nombre, descripcion: $descripcion, precio: $precio, stock: $stock, fotoUrl: $fotoUrl, activo: $activo)';
}


}

/// @nodoc
abstract mixin class _$ProductoCopyWith<$Res> implements $ProductoCopyWith<$Res> {
  factory _$ProductoCopyWith(_Producto value, $Res Function(_Producto) _then) = __$ProductoCopyWithImpl;
@override @useResult
$Res call({
 String id,@JsonKey(name: 'academia_id') String academiaId, String nombre, String? descripcion, num precio, int stock,@JsonKey(name: 'foto_url') String? fotoUrl, bool activo
});




}
/// @nodoc
class __$ProductoCopyWithImpl<$Res>
    implements _$ProductoCopyWith<$Res> {
  __$ProductoCopyWithImpl(this._self, this._then);

  final _Producto _self;
  final $Res Function(_Producto) _then;

/// Create a copy of Producto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? academiaId = null,Object? nombre = null,Object? descripcion = freezed,Object? precio = null,Object? stock = null,Object? fotoUrl = freezed,Object? activo = null,}) {
  return _then(_Producto(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,academiaId: null == academiaId ? _self.academiaId : academiaId // ignore: cast_nullable_to_non_nullable
as String,nombre: null == nombre ? _self.nombre : nombre // ignore: cast_nullable_to_non_nullable
as String,descripcion: freezed == descripcion ? _self.descripcion : descripcion // ignore: cast_nullable_to_non_nullable
as String?,precio: null == precio ? _self.precio : precio // ignore: cast_nullable_to_non_nullable
as num,stock: null == stock ? _self.stock : stock // ignore: cast_nullable_to_non_nullable
as int,fotoUrl: freezed == fotoUrl ? _self.fotoUrl : fotoUrl // ignore: cast_nullable_to_non_nullable
as String?,activo: null == activo ? _self.activo : activo // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
