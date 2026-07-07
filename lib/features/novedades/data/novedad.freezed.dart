// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'novedad.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$Novedad {

 String get id; String get academiaId; String get autorId; String? get autorNombre; String get titulo; String get contenido; bool get fijado; DateTime get createdAt;
/// Create a copy of Novedad
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NovedadCopyWith<Novedad> get copyWith => _$NovedadCopyWithImpl<Novedad>(this as Novedad, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Novedad&&(identical(other.id, id) || other.id == id)&&(identical(other.academiaId, academiaId) || other.academiaId == academiaId)&&(identical(other.autorId, autorId) || other.autorId == autorId)&&(identical(other.autorNombre, autorNombre) || other.autorNombre == autorNombre)&&(identical(other.titulo, titulo) || other.titulo == titulo)&&(identical(other.contenido, contenido) || other.contenido == contenido)&&(identical(other.fijado, fijado) || other.fijado == fijado)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}


@override
int get hashCode => Object.hash(runtimeType,id,academiaId,autorId,autorNombre,titulo,contenido,fijado,createdAt);

@override
String toString() {
  return 'Novedad(id: $id, academiaId: $academiaId, autorId: $autorId, autorNombre: $autorNombre, titulo: $titulo, contenido: $contenido, fijado: $fijado, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class $NovedadCopyWith<$Res>  {
  factory $NovedadCopyWith(Novedad value, $Res Function(Novedad) _then) = _$NovedadCopyWithImpl;
@useResult
$Res call({
 String id, String academiaId, String autorId, String? autorNombre, String titulo, String contenido, bool fijado, DateTime createdAt
});




}
/// @nodoc
class _$NovedadCopyWithImpl<$Res>
    implements $NovedadCopyWith<$Res> {
  _$NovedadCopyWithImpl(this._self, this._then);

  final Novedad _self;
  final $Res Function(Novedad) _then;

/// Create a copy of Novedad
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? academiaId = null,Object? autorId = null,Object? autorNombre = freezed,Object? titulo = null,Object? contenido = null,Object? fijado = null,Object? createdAt = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,academiaId: null == academiaId ? _self.academiaId : academiaId // ignore: cast_nullable_to_non_nullable
as String,autorId: null == autorId ? _self.autorId : autorId // ignore: cast_nullable_to_non_nullable
as String,autorNombre: freezed == autorNombre ? _self.autorNombre : autorNombre // ignore: cast_nullable_to_non_nullable
as String?,titulo: null == titulo ? _self.titulo : titulo // ignore: cast_nullable_to_non_nullable
as String,contenido: null == contenido ? _self.contenido : contenido // ignore: cast_nullable_to_non_nullable
as String,fijado: null == fijado ? _self.fijado : fijado // ignore: cast_nullable_to_non_nullable
as bool,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [Novedad].
extension NovedadPatterns on Novedad {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Novedad value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Novedad() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Novedad value)  $default,){
final _that = this;
switch (_that) {
case _Novedad():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Novedad value)?  $default,){
final _that = this;
switch (_that) {
case _Novedad() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String academiaId,  String autorId,  String? autorNombre,  String titulo,  String contenido,  bool fijado,  DateTime createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Novedad() when $default != null:
return $default(_that.id,_that.academiaId,_that.autorId,_that.autorNombre,_that.titulo,_that.contenido,_that.fijado,_that.createdAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String academiaId,  String autorId,  String? autorNombre,  String titulo,  String contenido,  bool fijado,  DateTime createdAt)  $default,) {final _that = this;
switch (_that) {
case _Novedad():
return $default(_that.id,_that.academiaId,_that.autorId,_that.autorNombre,_that.titulo,_that.contenido,_that.fijado,_that.createdAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String academiaId,  String autorId,  String? autorNombre,  String titulo,  String contenido,  bool fijado,  DateTime createdAt)?  $default,) {final _that = this;
switch (_that) {
case _Novedad() when $default != null:
return $default(_that.id,_that.academiaId,_that.autorId,_that.autorNombre,_that.titulo,_that.contenido,_that.fijado,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc


class _Novedad implements Novedad {
  const _Novedad({required this.id, required this.academiaId, required this.autorId, this.autorNombre, required this.titulo, required this.contenido, required this.fijado, required this.createdAt});
  

@override final  String id;
@override final  String academiaId;
@override final  String autorId;
@override final  String? autorNombre;
@override final  String titulo;
@override final  String contenido;
@override final  bool fijado;
@override final  DateTime createdAt;

/// Create a copy of Novedad
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$NovedadCopyWith<_Novedad> get copyWith => __$NovedadCopyWithImpl<_Novedad>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Novedad&&(identical(other.id, id) || other.id == id)&&(identical(other.academiaId, academiaId) || other.academiaId == academiaId)&&(identical(other.autorId, autorId) || other.autorId == autorId)&&(identical(other.autorNombre, autorNombre) || other.autorNombre == autorNombre)&&(identical(other.titulo, titulo) || other.titulo == titulo)&&(identical(other.contenido, contenido) || other.contenido == contenido)&&(identical(other.fijado, fijado) || other.fijado == fijado)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}


@override
int get hashCode => Object.hash(runtimeType,id,academiaId,autorId,autorNombre,titulo,contenido,fijado,createdAt);

@override
String toString() {
  return 'Novedad(id: $id, academiaId: $academiaId, autorId: $autorId, autorNombre: $autorNombre, titulo: $titulo, contenido: $contenido, fijado: $fijado, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$NovedadCopyWith<$Res> implements $NovedadCopyWith<$Res> {
  factory _$NovedadCopyWith(_Novedad value, $Res Function(_Novedad) _then) = __$NovedadCopyWithImpl;
@override @useResult
$Res call({
 String id, String academiaId, String autorId, String? autorNombre, String titulo, String contenido, bool fijado, DateTime createdAt
});




}
/// @nodoc
class __$NovedadCopyWithImpl<$Res>
    implements _$NovedadCopyWith<$Res> {
  __$NovedadCopyWithImpl(this._self, this._then);

  final _Novedad _self;
  final $Res Function(_Novedad) _then;

/// Create a copy of Novedad
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? academiaId = null,Object? autorId = null,Object? autorNombre = freezed,Object? titulo = null,Object? contenido = null,Object? fijado = null,Object? createdAt = null,}) {
  return _then(_Novedad(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,academiaId: null == academiaId ? _self.academiaId : academiaId // ignore: cast_nullable_to_non_nullable
as String,autorId: null == autorId ? _self.autorId : autorId // ignore: cast_nullable_to_non_nullable
as String,autorNombre: freezed == autorNombre ? _self.autorNombre : autorNombre // ignore: cast_nullable_to_non_nullable
as String?,titulo: null == titulo ? _self.titulo : titulo // ignore: cast_nullable_to_non_nullable
as String,contenido: null == contenido ? _self.contenido : contenido // ignore: cast_nullable_to_non_nullable
as String,fijado: null == fijado ? _self.fijado : fijado // ignore: cast_nullable_to_non_nullable
as bool,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

// dart format on
