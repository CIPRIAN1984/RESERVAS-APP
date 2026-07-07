// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'pedido.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$Pedido {

 String get id; String get alumnoId; String? get alumnoNombre; String get productoId; String? get productoNombre; int get cantidad; String get estado; num get precioSnapshot; String get paymentStatus; DateTime get createdAt;
/// Create a copy of Pedido
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PedidoCopyWith<Pedido> get copyWith => _$PedidoCopyWithImpl<Pedido>(this as Pedido, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Pedido&&(identical(other.id, id) || other.id == id)&&(identical(other.alumnoId, alumnoId) || other.alumnoId == alumnoId)&&(identical(other.alumnoNombre, alumnoNombre) || other.alumnoNombre == alumnoNombre)&&(identical(other.productoId, productoId) || other.productoId == productoId)&&(identical(other.productoNombre, productoNombre) || other.productoNombre == productoNombre)&&(identical(other.cantidad, cantidad) || other.cantidad == cantidad)&&(identical(other.estado, estado) || other.estado == estado)&&(identical(other.precioSnapshot, precioSnapshot) || other.precioSnapshot == precioSnapshot)&&(identical(other.paymentStatus, paymentStatus) || other.paymentStatus == paymentStatus)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}


@override
int get hashCode => Object.hash(runtimeType,id,alumnoId,alumnoNombre,productoId,productoNombre,cantidad,estado,precioSnapshot,paymentStatus,createdAt);

@override
String toString() {
  return 'Pedido(id: $id, alumnoId: $alumnoId, alumnoNombre: $alumnoNombre, productoId: $productoId, productoNombre: $productoNombre, cantidad: $cantidad, estado: $estado, precioSnapshot: $precioSnapshot, paymentStatus: $paymentStatus, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class $PedidoCopyWith<$Res>  {
  factory $PedidoCopyWith(Pedido value, $Res Function(Pedido) _then) = _$PedidoCopyWithImpl;
@useResult
$Res call({
 String id, String alumnoId, String? alumnoNombre, String productoId, String? productoNombre, int cantidad, String estado, num precioSnapshot, String paymentStatus, DateTime createdAt
});




}
/// @nodoc
class _$PedidoCopyWithImpl<$Res>
    implements $PedidoCopyWith<$Res> {
  _$PedidoCopyWithImpl(this._self, this._then);

  final Pedido _self;
  final $Res Function(Pedido) _then;

/// Create a copy of Pedido
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? alumnoId = null,Object? alumnoNombre = freezed,Object? productoId = null,Object? productoNombre = freezed,Object? cantidad = null,Object? estado = null,Object? precioSnapshot = null,Object? paymentStatus = null,Object? createdAt = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,alumnoId: null == alumnoId ? _self.alumnoId : alumnoId // ignore: cast_nullable_to_non_nullable
as String,alumnoNombre: freezed == alumnoNombre ? _self.alumnoNombre : alumnoNombre // ignore: cast_nullable_to_non_nullable
as String?,productoId: null == productoId ? _self.productoId : productoId // ignore: cast_nullable_to_non_nullable
as String,productoNombre: freezed == productoNombre ? _self.productoNombre : productoNombre // ignore: cast_nullable_to_non_nullable
as String?,cantidad: null == cantidad ? _self.cantidad : cantidad // ignore: cast_nullable_to_non_nullable
as int,estado: null == estado ? _self.estado : estado // ignore: cast_nullable_to_non_nullable
as String,precioSnapshot: null == precioSnapshot ? _self.precioSnapshot : precioSnapshot // ignore: cast_nullable_to_non_nullable
as num,paymentStatus: null == paymentStatus ? _self.paymentStatus : paymentStatus // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [Pedido].
extension PedidoPatterns on Pedido {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Pedido value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Pedido() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Pedido value)  $default,){
final _that = this;
switch (_that) {
case _Pedido():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Pedido value)?  $default,){
final _that = this;
switch (_that) {
case _Pedido() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String alumnoId,  String? alumnoNombre,  String productoId,  String? productoNombre,  int cantidad,  String estado,  num precioSnapshot,  String paymentStatus,  DateTime createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Pedido() when $default != null:
return $default(_that.id,_that.alumnoId,_that.alumnoNombre,_that.productoId,_that.productoNombre,_that.cantidad,_that.estado,_that.precioSnapshot,_that.paymentStatus,_that.createdAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String alumnoId,  String? alumnoNombre,  String productoId,  String? productoNombre,  int cantidad,  String estado,  num precioSnapshot,  String paymentStatus,  DateTime createdAt)  $default,) {final _that = this;
switch (_that) {
case _Pedido():
return $default(_that.id,_that.alumnoId,_that.alumnoNombre,_that.productoId,_that.productoNombre,_that.cantidad,_that.estado,_that.precioSnapshot,_that.paymentStatus,_that.createdAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String alumnoId,  String? alumnoNombre,  String productoId,  String? productoNombre,  int cantidad,  String estado,  num precioSnapshot,  String paymentStatus,  DateTime createdAt)?  $default,) {final _that = this;
switch (_that) {
case _Pedido() when $default != null:
return $default(_that.id,_that.alumnoId,_that.alumnoNombre,_that.productoId,_that.productoNombre,_that.cantidad,_that.estado,_that.precioSnapshot,_that.paymentStatus,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc


class _Pedido implements Pedido {
  const _Pedido({required this.id, required this.alumnoId, this.alumnoNombre, required this.productoId, this.productoNombre, required this.cantidad, required this.estado, required this.precioSnapshot, required this.paymentStatus, required this.createdAt});
  

@override final  String id;
@override final  String alumnoId;
@override final  String? alumnoNombre;
@override final  String productoId;
@override final  String? productoNombre;
@override final  int cantidad;
@override final  String estado;
@override final  num precioSnapshot;
@override final  String paymentStatus;
@override final  DateTime createdAt;

/// Create a copy of Pedido
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PedidoCopyWith<_Pedido> get copyWith => __$PedidoCopyWithImpl<_Pedido>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Pedido&&(identical(other.id, id) || other.id == id)&&(identical(other.alumnoId, alumnoId) || other.alumnoId == alumnoId)&&(identical(other.alumnoNombre, alumnoNombre) || other.alumnoNombre == alumnoNombre)&&(identical(other.productoId, productoId) || other.productoId == productoId)&&(identical(other.productoNombre, productoNombre) || other.productoNombre == productoNombre)&&(identical(other.cantidad, cantidad) || other.cantidad == cantidad)&&(identical(other.estado, estado) || other.estado == estado)&&(identical(other.precioSnapshot, precioSnapshot) || other.precioSnapshot == precioSnapshot)&&(identical(other.paymentStatus, paymentStatus) || other.paymentStatus == paymentStatus)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}


@override
int get hashCode => Object.hash(runtimeType,id,alumnoId,alumnoNombre,productoId,productoNombre,cantidad,estado,precioSnapshot,paymentStatus,createdAt);

@override
String toString() {
  return 'Pedido(id: $id, alumnoId: $alumnoId, alumnoNombre: $alumnoNombre, productoId: $productoId, productoNombre: $productoNombre, cantidad: $cantidad, estado: $estado, precioSnapshot: $precioSnapshot, paymentStatus: $paymentStatus, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$PedidoCopyWith<$Res> implements $PedidoCopyWith<$Res> {
  factory _$PedidoCopyWith(_Pedido value, $Res Function(_Pedido) _then) = __$PedidoCopyWithImpl;
@override @useResult
$Res call({
 String id, String alumnoId, String? alumnoNombre, String productoId, String? productoNombre, int cantidad, String estado, num precioSnapshot, String paymentStatus, DateTime createdAt
});




}
/// @nodoc
class __$PedidoCopyWithImpl<$Res>
    implements _$PedidoCopyWith<$Res> {
  __$PedidoCopyWithImpl(this._self, this._then);

  final _Pedido _self;
  final $Res Function(_Pedido) _then;

/// Create a copy of Pedido
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? alumnoId = null,Object? alumnoNombre = freezed,Object? productoId = null,Object? productoNombre = freezed,Object? cantidad = null,Object? estado = null,Object? precioSnapshot = null,Object? paymentStatus = null,Object? createdAt = null,}) {
  return _then(_Pedido(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,alumnoId: null == alumnoId ? _self.alumnoId : alumnoId // ignore: cast_nullable_to_non_nullable
as String,alumnoNombre: freezed == alumnoNombre ? _self.alumnoNombre : alumnoNombre // ignore: cast_nullable_to_non_nullable
as String?,productoId: null == productoId ? _self.productoId : productoId // ignore: cast_nullable_to_non_nullable
as String,productoNombre: freezed == productoNombre ? _self.productoNombre : productoNombre // ignore: cast_nullable_to_non_nullable
as String?,cantidad: null == cantidad ? _self.cantidad : cantidad // ignore: cast_nullable_to_non_nullable
as int,estado: null == estado ? _self.estado : estado // ignore: cast_nullable_to_non_nullable
as String,precioSnapshot: null == precioSnapshot ? _self.precioSnapshot : precioSnapshot // ignore: cast_nullable_to_non_nullable
as num,paymentStatus: null == paymentStatus ? _self.paymentStatus : paymentStatus // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

// dart format on
