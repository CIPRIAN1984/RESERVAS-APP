// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'prestamo.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$Prestamo {

 String get id; String get alumnoId; String? get alumnoNombre; String? get productoId; String? get productoNombre; String? get descripcion; DateTime get fechaPrestamo; DateTime? get fechaDevolucion;
/// Create a copy of Prestamo
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PrestamoCopyWith<Prestamo> get copyWith => _$PrestamoCopyWithImpl<Prestamo>(this as Prestamo, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Prestamo&&(identical(other.id, id) || other.id == id)&&(identical(other.alumnoId, alumnoId) || other.alumnoId == alumnoId)&&(identical(other.alumnoNombre, alumnoNombre) || other.alumnoNombre == alumnoNombre)&&(identical(other.productoId, productoId) || other.productoId == productoId)&&(identical(other.productoNombre, productoNombre) || other.productoNombre == productoNombre)&&(identical(other.descripcion, descripcion) || other.descripcion == descripcion)&&(identical(other.fechaPrestamo, fechaPrestamo) || other.fechaPrestamo == fechaPrestamo)&&(identical(other.fechaDevolucion, fechaDevolucion) || other.fechaDevolucion == fechaDevolucion));
}


@override
int get hashCode => Object.hash(runtimeType,id,alumnoId,alumnoNombre,productoId,productoNombre,descripcion,fechaPrestamo,fechaDevolucion);

@override
String toString() {
  return 'Prestamo(id: $id, alumnoId: $alumnoId, alumnoNombre: $alumnoNombre, productoId: $productoId, productoNombre: $productoNombre, descripcion: $descripcion, fechaPrestamo: $fechaPrestamo, fechaDevolucion: $fechaDevolucion)';
}


}

/// @nodoc
abstract mixin class $PrestamoCopyWith<$Res>  {
  factory $PrestamoCopyWith(Prestamo value, $Res Function(Prestamo) _then) = _$PrestamoCopyWithImpl;
@useResult
$Res call({
 String id, String alumnoId, String? alumnoNombre, String? productoId, String? productoNombre, String? descripcion, DateTime fechaPrestamo, DateTime? fechaDevolucion
});




}
/// @nodoc
class _$PrestamoCopyWithImpl<$Res>
    implements $PrestamoCopyWith<$Res> {
  _$PrestamoCopyWithImpl(this._self, this._then);

  final Prestamo _self;
  final $Res Function(Prestamo) _then;

/// Create a copy of Prestamo
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? alumnoId = null,Object? alumnoNombre = freezed,Object? productoId = freezed,Object? productoNombre = freezed,Object? descripcion = freezed,Object? fechaPrestamo = null,Object? fechaDevolucion = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,alumnoId: null == alumnoId ? _self.alumnoId : alumnoId // ignore: cast_nullable_to_non_nullable
as String,alumnoNombre: freezed == alumnoNombre ? _self.alumnoNombre : alumnoNombre // ignore: cast_nullable_to_non_nullable
as String?,productoId: freezed == productoId ? _self.productoId : productoId // ignore: cast_nullable_to_non_nullable
as String?,productoNombre: freezed == productoNombre ? _self.productoNombre : productoNombre // ignore: cast_nullable_to_non_nullable
as String?,descripcion: freezed == descripcion ? _self.descripcion : descripcion // ignore: cast_nullable_to_non_nullable
as String?,fechaPrestamo: null == fechaPrestamo ? _self.fechaPrestamo : fechaPrestamo // ignore: cast_nullable_to_non_nullable
as DateTime,fechaDevolucion: freezed == fechaDevolucion ? _self.fechaDevolucion : fechaDevolucion // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [Prestamo].
extension PrestamoPatterns on Prestamo {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Prestamo value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Prestamo() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Prestamo value)  $default,){
final _that = this;
switch (_that) {
case _Prestamo():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Prestamo value)?  $default,){
final _that = this;
switch (_that) {
case _Prestamo() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String alumnoId,  String? alumnoNombre,  String? productoId,  String? productoNombre,  String? descripcion,  DateTime fechaPrestamo,  DateTime? fechaDevolucion)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Prestamo() when $default != null:
return $default(_that.id,_that.alumnoId,_that.alumnoNombre,_that.productoId,_that.productoNombre,_that.descripcion,_that.fechaPrestamo,_that.fechaDevolucion);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String alumnoId,  String? alumnoNombre,  String? productoId,  String? productoNombre,  String? descripcion,  DateTime fechaPrestamo,  DateTime? fechaDevolucion)  $default,) {final _that = this;
switch (_that) {
case _Prestamo():
return $default(_that.id,_that.alumnoId,_that.alumnoNombre,_that.productoId,_that.productoNombre,_that.descripcion,_that.fechaPrestamo,_that.fechaDevolucion);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String alumnoId,  String? alumnoNombre,  String? productoId,  String? productoNombre,  String? descripcion,  DateTime fechaPrestamo,  DateTime? fechaDevolucion)?  $default,) {final _that = this;
switch (_that) {
case _Prestamo() when $default != null:
return $default(_that.id,_that.alumnoId,_that.alumnoNombre,_that.productoId,_that.productoNombre,_that.descripcion,_that.fechaPrestamo,_that.fechaDevolucion);case _:
  return null;

}
}

}

/// @nodoc


class _Prestamo extends Prestamo {
  const _Prestamo({required this.id, required this.alumnoId, this.alumnoNombre, this.productoId, this.productoNombre, this.descripcion, required this.fechaPrestamo, this.fechaDevolucion}): super._();
  

@override final  String id;
@override final  String alumnoId;
@override final  String? alumnoNombre;
@override final  String? productoId;
@override final  String? productoNombre;
@override final  String? descripcion;
@override final  DateTime fechaPrestamo;
@override final  DateTime? fechaDevolucion;

/// Create a copy of Prestamo
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PrestamoCopyWith<_Prestamo> get copyWith => __$PrestamoCopyWithImpl<_Prestamo>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Prestamo&&(identical(other.id, id) || other.id == id)&&(identical(other.alumnoId, alumnoId) || other.alumnoId == alumnoId)&&(identical(other.alumnoNombre, alumnoNombre) || other.alumnoNombre == alumnoNombre)&&(identical(other.productoId, productoId) || other.productoId == productoId)&&(identical(other.productoNombre, productoNombre) || other.productoNombre == productoNombre)&&(identical(other.descripcion, descripcion) || other.descripcion == descripcion)&&(identical(other.fechaPrestamo, fechaPrestamo) || other.fechaPrestamo == fechaPrestamo)&&(identical(other.fechaDevolucion, fechaDevolucion) || other.fechaDevolucion == fechaDevolucion));
}


@override
int get hashCode => Object.hash(runtimeType,id,alumnoId,alumnoNombre,productoId,productoNombre,descripcion,fechaPrestamo,fechaDevolucion);

@override
String toString() {
  return 'Prestamo(id: $id, alumnoId: $alumnoId, alumnoNombre: $alumnoNombre, productoId: $productoId, productoNombre: $productoNombre, descripcion: $descripcion, fechaPrestamo: $fechaPrestamo, fechaDevolucion: $fechaDevolucion)';
}


}

/// @nodoc
abstract mixin class _$PrestamoCopyWith<$Res> implements $PrestamoCopyWith<$Res> {
  factory _$PrestamoCopyWith(_Prestamo value, $Res Function(_Prestamo) _then) = __$PrestamoCopyWithImpl;
@override @useResult
$Res call({
 String id, String alumnoId, String? alumnoNombre, String? productoId, String? productoNombre, String? descripcion, DateTime fechaPrestamo, DateTime? fechaDevolucion
});




}
/// @nodoc
class __$PrestamoCopyWithImpl<$Res>
    implements _$PrestamoCopyWith<$Res> {
  __$PrestamoCopyWithImpl(this._self, this._then);

  final _Prestamo _self;
  final $Res Function(_Prestamo) _then;

/// Create a copy of Prestamo
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? alumnoId = null,Object? alumnoNombre = freezed,Object? productoId = freezed,Object? productoNombre = freezed,Object? descripcion = freezed,Object? fechaPrestamo = null,Object? fechaDevolucion = freezed,}) {
  return _then(_Prestamo(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,alumnoId: null == alumnoId ? _self.alumnoId : alumnoId // ignore: cast_nullable_to_non_nullable
as String,alumnoNombre: freezed == alumnoNombre ? _self.alumnoNombre : alumnoNombre // ignore: cast_nullable_to_non_nullable
as String?,productoId: freezed == productoId ? _self.productoId : productoId // ignore: cast_nullable_to_non_nullable
as String?,productoNombre: freezed == productoNombre ? _self.productoNombre : productoNombre // ignore: cast_nullable_to_non_nullable
as String?,descripcion: freezed == descripcion ? _self.descripcion : descripcion // ignore: cast_nullable_to_non_nullable
as String?,fechaPrestamo: null == fechaPrestamo ? _self.fechaPrestamo : fechaPrestamo // ignore: cast_nullable_to_non_nullable
as DateTime,fechaDevolucion: freezed == fechaDevolucion ? _self.fechaDevolucion : fechaDevolucion // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
