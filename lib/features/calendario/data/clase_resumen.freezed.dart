// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'clase_resumen.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ClaseResumen {

 String get id; String get titulo; String? get descripcion;@JsonKey(name: 'fecha_hora_inicio') DateTime get fechaHoraInicio;@JsonKey(name: 'fecha_hora_fin') DateTime get fechaHoraFin;@JsonKey(name: 'aforo_maximo') int get aforoMaximo;@JsonKey(name: 'profesor_id') String get profesorId;@JsonKey(name: 'profesor_nombre') String get profesorNombre;@JsonKey(name: 'inscritos_count') int get inscritosCount;@JsonKey(name: 'mi_estado') String? get miEstado; String get estado;
/// Create a copy of ClaseResumen
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ClaseResumenCopyWith<ClaseResumen> get copyWith => _$ClaseResumenCopyWithImpl<ClaseResumen>(this as ClaseResumen, _$identity);

  /// Serializes this ClaseResumen to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ClaseResumen&&(identical(other.id, id) || other.id == id)&&(identical(other.titulo, titulo) || other.titulo == titulo)&&(identical(other.descripcion, descripcion) || other.descripcion == descripcion)&&(identical(other.fechaHoraInicio, fechaHoraInicio) || other.fechaHoraInicio == fechaHoraInicio)&&(identical(other.fechaHoraFin, fechaHoraFin) || other.fechaHoraFin == fechaHoraFin)&&(identical(other.aforoMaximo, aforoMaximo) || other.aforoMaximo == aforoMaximo)&&(identical(other.profesorId, profesorId) || other.profesorId == profesorId)&&(identical(other.profesorNombre, profesorNombre) || other.profesorNombre == profesorNombre)&&(identical(other.inscritosCount, inscritosCount) || other.inscritosCount == inscritosCount)&&(identical(other.miEstado, miEstado) || other.miEstado == miEstado)&&(identical(other.estado, estado) || other.estado == estado));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,titulo,descripcion,fechaHoraInicio,fechaHoraFin,aforoMaximo,profesorId,profesorNombre,inscritosCount,miEstado,estado);

@override
String toString() {
  return 'ClaseResumen(id: $id, titulo: $titulo, descripcion: $descripcion, fechaHoraInicio: $fechaHoraInicio, fechaHoraFin: $fechaHoraFin, aforoMaximo: $aforoMaximo, profesorId: $profesorId, profesorNombre: $profesorNombre, inscritosCount: $inscritosCount, miEstado: $miEstado, estado: $estado)';
}


}

/// @nodoc
abstract mixin class $ClaseResumenCopyWith<$Res>  {
  factory $ClaseResumenCopyWith(ClaseResumen value, $Res Function(ClaseResumen) _then) = _$ClaseResumenCopyWithImpl;
@useResult
$Res call({
 String id, String titulo, String? descripcion,@JsonKey(name: 'fecha_hora_inicio') DateTime fechaHoraInicio,@JsonKey(name: 'fecha_hora_fin') DateTime fechaHoraFin,@JsonKey(name: 'aforo_maximo') int aforoMaximo,@JsonKey(name: 'profesor_id') String profesorId,@JsonKey(name: 'profesor_nombre') String profesorNombre,@JsonKey(name: 'inscritos_count') int inscritosCount,@JsonKey(name: 'mi_estado') String? miEstado, String estado
});




}
/// @nodoc
class _$ClaseResumenCopyWithImpl<$Res>
    implements $ClaseResumenCopyWith<$Res> {
  _$ClaseResumenCopyWithImpl(this._self, this._then);

  final ClaseResumen _self;
  final $Res Function(ClaseResumen) _then;

/// Create a copy of ClaseResumen
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? titulo = null,Object? descripcion = freezed,Object? fechaHoraInicio = null,Object? fechaHoraFin = null,Object? aforoMaximo = null,Object? profesorId = null,Object? profesorNombre = null,Object? inscritosCount = null,Object? miEstado = freezed,Object? estado = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,titulo: null == titulo ? _self.titulo : titulo // ignore: cast_nullable_to_non_nullable
as String,descripcion: freezed == descripcion ? _self.descripcion : descripcion // ignore: cast_nullable_to_non_nullable
as String?,fechaHoraInicio: null == fechaHoraInicio ? _self.fechaHoraInicio : fechaHoraInicio // ignore: cast_nullable_to_non_nullable
as DateTime,fechaHoraFin: null == fechaHoraFin ? _self.fechaHoraFin : fechaHoraFin // ignore: cast_nullable_to_non_nullable
as DateTime,aforoMaximo: null == aforoMaximo ? _self.aforoMaximo : aforoMaximo // ignore: cast_nullable_to_non_nullable
as int,profesorId: null == profesorId ? _self.profesorId : profesorId // ignore: cast_nullable_to_non_nullable
as String,profesorNombre: null == profesorNombre ? _self.profesorNombre : profesorNombre // ignore: cast_nullable_to_non_nullable
as String,inscritosCount: null == inscritosCount ? _self.inscritosCount : inscritosCount // ignore: cast_nullable_to_non_nullable
as int,miEstado: freezed == miEstado ? _self.miEstado : miEstado // ignore: cast_nullable_to_non_nullable
as String?,estado: null == estado ? _self.estado : estado // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [ClaseResumen].
extension ClaseResumenPatterns on ClaseResumen {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ClaseResumen value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ClaseResumen() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ClaseResumen value)  $default,){
final _that = this;
switch (_that) {
case _ClaseResumen():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ClaseResumen value)?  $default,){
final _that = this;
switch (_that) {
case _ClaseResumen() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String titulo,  String? descripcion, @JsonKey(name: 'fecha_hora_inicio')  DateTime fechaHoraInicio, @JsonKey(name: 'fecha_hora_fin')  DateTime fechaHoraFin, @JsonKey(name: 'aforo_maximo')  int aforoMaximo, @JsonKey(name: 'profesor_id')  String profesorId, @JsonKey(name: 'profesor_nombre')  String profesorNombre, @JsonKey(name: 'inscritos_count')  int inscritosCount, @JsonKey(name: 'mi_estado')  String? miEstado,  String estado)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ClaseResumen() when $default != null:
return $default(_that.id,_that.titulo,_that.descripcion,_that.fechaHoraInicio,_that.fechaHoraFin,_that.aforoMaximo,_that.profesorId,_that.profesorNombre,_that.inscritosCount,_that.miEstado,_that.estado);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String titulo,  String? descripcion, @JsonKey(name: 'fecha_hora_inicio')  DateTime fechaHoraInicio, @JsonKey(name: 'fecha_hora_fin')  DateTime fechaHoraFin, @JsonKey(name: 'aforo_maximo')  int aforoMaximo, @JsonKey(name: 'profesor_id')  String profesorId, @JsonKey(name: 'profesor_nombre')  String profesorNombre, @JsonKey(name: 'inscritos_count')  int inscritosCount, @JsonKey(name: 'mi_estado')  String? miEstado,  String estado)  $default,) {final _that = this;
switch (_that) {
case _ClaseResumen():
return $default(_that.id,_that.titulo,_that.descripcion,_that.fechaHoraInicio,_that.fechaHoraFin,_that.aforoMaximo,_that.profesorId,_that.profesorNombre,_that.inscritosCount,_that.miEstado,_that.estado);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String titulo,  String? descripcion, @JsonKey(name: 'fecha_hora_inicio')  DateTime fechaHoraInicio, @JsonKey(name: 'fecha_hora_fin')  DateTime fechaHoraFin, @JsonKey(name: 'aforo_maximo')  int aforoMaximo, @JsonKey(name: 'profesor_id')  String profesorId, @JsonKey(name: 'profesor_nombre')  String profesorNombre, @JsonKey(name: 'inscritos_count')  int inscritosCount, @JsonKey(name: 'mi_estado')  String? miEstado,  String estado)?  $default,) {final _that = this;
switch (_that) {
case _ClaseResumen() when $default != null:
return $default(_that.id,_that.titulo,_that.descripcion,_that.fechaHoraInicio,_that.fechaHoraFin,_that.aforoMaximo,_that.profesorId,_that.profesorNombre,_that.inscritosCount,_that.miEstado,_that.estado);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ClaseResumen extends ClaseResumen {
  const _ClaseResumen({required this.id, required this.titulo, this.descripcion, @JsonKey(name: 'fecha_hora_inicio') required this.fechaHoraInicio, @JsonKey(name: 'fecha_hora_fin') required this.fechaHoraFin, @JsonKey(name: 'aforo_maximo') required this.aforoMaximo, @JsonKey(name: 'profesor_id') required this.profesorId, @JsonKey(name: 'profesor_nombre') required this.profesorNombre, @JsonKey(name: 'inscritos_count') required this.inscritosCount, @JsonKey(name: 'mi_estado') this.miEstado, this.estado = 'activa'}): super._();
  factory _ClaseResumen.fromJson(Map<String, dynamic> json) => _$ClaseResumenFromJson(json);

@override final  String id;
@override final  String titulo;
@override final  String? descripcion;
@override@JsonKey(name: 'fecha_hora_inicio') final  DateTime fechaHoraInicio;
@override@JsonKey(name: 'fecha_hora_fin') final  DateTime fechaHoraFin;
@override@JsonKey(name: 'aforo_maximo') final  int aforoMaximo;
@override@JsonKey(name: 'profesor_id') final  String profesorId;
@override@JsonKey(name: 'profesor_nombre') final  String profesorNombre;
@override@JsonKey(name: 'inscritos_count') final  int inscritosCount;
@override@JsonKey(name: 'mi_estado') final  String? miEstado;
@override@JsonKey() final  String estado;

/// Create a copy of ClaseResumen
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ClaseResumenCopyWith<_ClaseResumen> get copyWith => __$ClaseResumenCopyWithImpl<_ClaseResumen>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ClaseResumenToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ClaseResumen&&(identical(other.id, id) || other.id == id)&&(identical(other.titulo, titulo) || other.titulo == titulo)&&(identical(other.descripcion, descripcion) || other.descripcion == descripcion)&&(identical(other.fechaHoraInicio, fechaHoraInicio) || other.fechaHoraInicio == fechaHoraInicio)&&(identical(other.fechaHoraFin, fechaHoraFin) || other.fechaHoraFin == fechaHoraFin)&&(identical(other.aforoMaximo, aforoMaximo) || other.aforoMaximo == aforoMaximo)&&(identical(other.profesorId, profesorId) || other.profesorId == profesorId)&&(identical(other.profesorNombre, profesorNombre) || other.profesorNombre == profesorNombre)&&(identical(other.inscritosCount, inscritosCount) || other.inscritosCount == inscritosCount)&&(identical(other.miEstado, miEstado) || other.miEstado == miEstado)&&(identical(other.estado, estado) || other.estado == estado));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,titulo,descripcion,fechaHoraInicio,fechaHoraFin,aforoMaximo,profesorId,profesorNombre,inscritosCount,miEstado,estado);

@override
String toString() {
  return 'ClaseResumen(id: $id, titulo: $titulo, descripcion: $descripcion, fechaHoraInicio: $fechaHoraInicio, fechaHoraFin: $fechaHoraFin, aforoMaximo: $aforoMaximo, profesorId: $profesorId, profesorNombre: $profesorNombre, inscritosCount: $inscritosCount, miEstado: $miEstado, estado: $estado)';
}


}

/// @nodoc
abstract mixin class _$ClaseResumenCopyWith<$Res> implements $ClaseResumenCopyWith<$Res> {
  factory _$ClaseResumenCopyWith(_ClaseResumen value, $Res Function(_ClaseResumen) _then) = __$ClaseResumenCopyWithImpl;
@override @useResult
$Res call({
 String id, String titulo, String? descripcion,@JsonKey(name: 'fecha_hora_inicio') DateTime fechaHoraInicio,@JsonKey(name: 'fecha_hora_fin') DateTime fechaHoraFin,@JsonKey(name: 'aforo_maximo') int aforoMaximo,@JsonKey(name: 'profesor_id') String profesorId,@JsonKey(name: 'profesor_nombre') String profesorNombre,@JsonKey(name: 'inscritos_count') int inscritosCount,@JsonKey(name: 'mi_estado') String? miEstado, String estado
});




}
/// @nodoc
class __$ClaseResumenCopyWithImpl<$Res>
    implements _$ClaseResumenCopyWith<$Res> {
  __$ClaseResumenCopyWithImpl(this._self, this._then);

  final _ClaseResumen _self;
  final $Res Function(_ClaseResumen) _then;

/// Create a copy of ClaseResumen
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? titulo = null,Object? descripcion = freezed,Object? fechaHoraInicio = null,Object? fechaHoraFin = null,Object? aforoMaximo = null,Object? profesorId = null,Object? profesorNombre = null,Object? inscritosCount = null,Object? miEstado = freezed,Object? estado = null,}) {
  return _then(_ClaseResumen(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,titulo: null == titulo ? _self.titulo : titulo // ignore: cast_nullable_to_non_nullable
as String,descripcion: freezed == descripcion ? _self.descripcion : descripcion // ignore: cast_nullable_to_non_nullable
as String?,fechaHoraInicio: null == fechaHoraInicio ? _self.fechaHoraInicio : fechaHoraInicio // ignore: cast_nullable_to_non_nullable
as DateTime,fechaHoraFin: null == fechaHoraFin ? _self.fechaHoraFin : fechaHoraFin // ignore: cast_nullable_to_non_nullable
as DateTime,aforoMaximo: null == aforoMaximo ? _self.aforoMaximo : aforoMaximo // ignore: cast_nullable_to_non_nullable
as int,profesorId: null == profesorId ? _self.profesorId : profesorId // ignore: cast_nullable_to_non_nullable
as String,profesorNombre: null == profesorNombre ? _self.profesorNombre : profesorNombre // ignore: cast_nullable_to_non_nullable
as String,inscritosCount: null == inscritosCount ? _self.inscritosCount : inscritosCount // ignore: cast_nullable_to_non_nullable
as int,miEstado: freezed == miEstado ? _self.miEstado : miEstado // ignore: cast_nullable_to_non_nullable
as String?,estado: null == estado ? _self.estado : estado // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
