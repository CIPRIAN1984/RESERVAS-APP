// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'documento_alumno.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$DocumentoAlumno {

 String get id;@JsonKey(name: 'academia_id') String get academiaId;@JsonKey(name: 'alumno_id') String get alumnoId; String get tipo;@JsonKey(name: 'storage_path') String get storagePath;@JsonKey(name: 'subido_por') String get subidoPor;@JsonKey(name: 'created_at') DateTime get createdAt;
/// Create a copy of DocumentoAlumno
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DocumentoAlumnoCopyWith<DocumentoAlumno> get copyWith => _$DocumentoAlumnoCopyWithImpl<DocumentoAlumno>(this as DocumentoAlumno, _$identity);

  /// Serializes this DocumentoAlumno to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DocumentoAlumno&&(identical(other.id, id) || other.id == id)&&(identical(other.academiaId, academiaId) || other.academiaId == academiaId)&&(identical(other.alumnoId, alumnoId) || other.alumnoId == alumnoId)&&(identical(other.tipo, tipo) || other.tipo == tipo)&&(identical(other.storagePath, storagePath) || other.storagePath == storagePath)&&(identical(other.subidoPor, subidoPor) || other.subidoPor == subidoPor)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,academiaId,alumnoId,tipo,storagePath,subidoPor,createdAt);

@override
String toString() {
  return 'DocumentoAlumno(id: $id, academiaId: $academiaId, alumnoId: $alumnoId, tipo: $tipo, storagePath: $storagePath, subidoPor: $subidoPor, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class $DocumentoAlumnoCopyWith<$Res>  {
  factory $DocumentoAlumnoCopyWith(DocumentoAlumno value, $Res Function(DocumentoAlumno) _then) = _$DocumentoAlumnoCopyWithImpl;
@useResult
$Res call({
 String id,@JsonKey(name: 'academia_id') String academiaId,@JsonKey(name: 'alumno_id') String alumnoId, String tipo,@JsonKey(name: 'storage_path') String storagePath,@JsonKey(name: 'subido_por') String subidoPor,@JsonKey(name: 'created_at') DateTime createdAt
});




}
/// @nodoc
class _$DocumentoAlumnoCopyWithImpl<$Res>
    implements $DocumentoAlumnoCopyWith<$Res> {
  _$DocumentoAlumnoCopyWithImpl(this._self, this._then);

  final DocumentoAlumno _self;
  final $Res Function(DocumentoAlumno) _then;

/// Create a copy of DocumentoAlumno
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? academiaId = null,Object? alumnoId = null,Object? tipo = null,Object? storagePath = null,Object? subidoPor = null,Object? createdAt = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,academiaId: null == academiaId ? _self.academiaId : academiaId // ignore: cast_nullable_to_non_nullable
as String,alumnoId: null == alumnoId ? _self.alumnoId : alumnoId // ignore: cast_nullable_to_non_nullable
as String,tipo: null == tipo ? _self.tipo : tipo // ignore: cast_nullable_to_non_nullable
as String,storagePath: null == storagePath ? _self.storagePath : storagePath // ignore: cast_nullable_to_non_nullable
as String,subidoPor: null == subidoPor ? _self.subidoPor : subidoPor // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [DocumentoAlumno].
extension DocumentoAlumnoPatterns on DocumentoAlumno {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DocumentoAlumno value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DocumentoAlumno() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DocumentoAlumno value)  $default,){
final _that = this;
switch (_that) {
case _DocumentoAlumno():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DocumentoAlumno value)?  $default,){
final _that = this;
switch (_that) {
case _DocumentoAlumno() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'academia_id')  String academiaId, @JsonKey(name: 'alumno_id')  String alumnoId,  String tipo, @JsonKey(name: 'storage_path')  String storagePath, @JsonKey(name: 'subido_por')  String subidoPor, @JsonKey(name: 'created_at')  DateTime createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DocumentoAlumno() when $default != null:
return $default(_that.id,_that.academiaId,_that.alumnoId,_that.tipo,_that.storagePath,_that.subidoPor,_that.createdAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'academia_id')  String academiaId, @JsonKey(name: 'alumno_id')  String alumnoId,  String tipo, @JsonKey(name: 'storage_path')  String storagePath, @JsonKey(name: 'subido_por')  String subidoPor, @JsonKey(name: 'created_at')  DateTime createdAt)  $default,) {final _that = this;
switch (_that) {
case _DocumentoAlumno():
return $default(_that.id,_that.academiaId,_that.alumnoId,_that.tipo,_that.storagePath,_that.subidoPor,_that.createdAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id, @JsonKey(name: 'academia_id')  String academiaId, @JsonKey(name: 'alumno_id')  String alumnoId,  String tipo, @JsonKey(name: 'storage_path')  String storagePath, @JsonKey(name: 'subido_por')  String subidoPor, @JsonKey(name: 'created_at')  DateTime createdAt)?  $default,) {final _that = this;
switch (_that) {
case _DocumentoAlumno() when $default != null:
return $default(_that.id,_that.academiaId,_that.alumnoId,_that.tipo,_that.storagePath,_that.subidoPor,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _DocumentoAlumno implements DocumentoAlumno {
  const _DocumentoAlumno({required this.id, @JsonKey(name: 'academia_id') required this.academiaId, @JsonKey(name: 'alumno_id') required this.alumnoId, required this.tipo, @JsonKey(name: 'storage_path') required this.storagePath, @JsonKey(name: 'subido_por') required this.subidoPor, @JsonKey(name: 'created_at') required this.createdAt});
  factory _DocumentoAlumno.fromJson(Map<String, dynamic> json) => _$DocumentoAlumnoFromJson(json);

@override final  String id;
@override@JsonKey(name: 'academia_id') final  String academiaId;
@override@JsonKey(name: 'alumno_id') final  String alumnoId;
@override final  String tipo;
@override@JsonKey(name: 'storage_path') final  String storagePath;
@override@JsonKey(name: 'subido_por') final  String subidoPor;
@override@JsonKey(name: 'created_at') final  DateTime createdAt;

/// Create a copy of DocumentoAlumno
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DocumentoAlumnoCopyWith<_DocumentoAlumno> get copyWith => __$DocumentoAlumnoCopyWithImpl<_DocumentoAlumno>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DocumentoAlumnoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DocumentoAlumno&&(identical(other.id, id) || other.id == id)&&(identical(other.academiaId, academiaId) || other.academiaId == academiaId)&&(identical(other.alumnoId, alumnoId) || other.alumnoId == alumnoId)&&(identical(other.tipo, tipo) || other.tipo == tipo)&&(identical(other.storagePath, storagePath) || other.storagePath == storagePath)&&(identical(other.subidoPor, subidoPor) || other.subidoPor == subidoPor)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,academiaId,alumnoId,tipo,storagePath,subidoPor,createdAt);

@override
String toString() {
  return 'DocumentoAlumno(id: $id, academiaId: $academiaId, alumnoId: $alumnoId, tipo: $tipo, storagePath: $storagePath, subidoPor: $subidoPor, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$DocumentoAlumnoCopyWith<$Res> implements $DocumentoAlumnoCopyWith<$Res> {
  factory _$DocumentoAlumnoCopyWith(_DocumentoAlumno value, $Res Function(_DocumentoAlumno) _then) = __$DocumentoAlumnoCopyWithImpl;
@override @useResult
$Res call({
 String id,@JsonKey(name: 'academia_id') String academiaId,@JsonKey(name: 'alumno_id') String alumnoId, String tipo,@JsonKey(name: 'storage_path') String storagePath,@JsonKey(name: 'subido_por') String subidoPor,@JsonKey(name: 'created_at') DateTime createdAt
});




}
/// @nodoc
class __$DocumentoAlumnoCopyWithImpl<$Res>
    implements _$DocumentoAlumnoCopyWith<$Res> {
  __$DocumentoAlumnoCopyWithImpl(this._self, this._then);

  final _DocumentoAlumno _self;
  final $Res Function(_DocumentoAlumno) _then;

/// Create a copy of DocumentoAlumno
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? academiaId = null,Object? alumnoId = null,Object? tipo = null,Object? storagePath = null,Object? subidoPor = null,Object? createdAt = null,}) {
  return _then(_DocumentoAlumno(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,academiaId: null == academiaId ? _self.academiaId : academiaId // ignore: cast_nullable_to_non_nullable
as String,alumnoId: null == alumnoId ? _self.alumnoId : alumnoId // ignore: cast_nullable_to_non_nullable
as String,tipo: null == tipo ? _self.tipo : tipo // ignore: cast_nullable_to_non_nullable
as String,storagePath: null == storagePath ? _self.storagePath : storagePath // ignore: cast_nullable_to_non_nullable
as String,subidoPor: null == subidoPor ? _self.subidoPor : subidoPor // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

// dart format on
