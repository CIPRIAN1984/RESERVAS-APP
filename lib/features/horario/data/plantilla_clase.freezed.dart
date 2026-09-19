// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'plantilla_clase.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$PlantillaClase {

 String get id;@JsonKey(name: 'academia_id') String get academiaId;@JsonKey(name: 'profesor_id') String get profesorId;@JsonKey(name: 'profesor_nombre') String get profesorNombre; String get titulo; String? get descripcion;/// 0 = domingo … 6 = sábado, igual que `extract(dow from …)` en
/// Postgres — así se guarda tal cual, sin traducir en ningún sitio.
@JsonKey(name: 'dia_semana') int get diaSemana;/// 'HH:mm', hora local de la academia.
@JsonKey(name: 'hora_inicio') String get horaInicio;@JsonKey(name: 'duracion_min') int get duracionMin;@JsonKey(name: 'aforo_maximo') int get aforoMaximo; bool get activo;
/// Create a copy of PlantillaClase
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PlantillaClaseCopyWith<PlantillaClase> get copyWith => _$PlantillaClaseCopyWithImpl<PlantillaClase>(this as PlantillaClase, _$identity);

  /// Serializes this PlantillaClase to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PlantillaClase&&(identical(other.id, id) || other.id == id)&&(identical(other.academiaId, academiaId) || other.academiaId == academiaId)&&(identical(other.profesorId, profesorId) || other.profesorId == profesorId)&&(identical(other.profesorNombre, profesorNombre) || other.profesorNombre == profesorNombre)&&(identical(other.titulo, titulo) || other.titulo == titulo)&&(identical(other.descripcion, descripcion) || other.descripcion == descripcion)&&(identical(other.diaSemana, diaSemana) || other.diaSemana == diaSemana)&&(identical(other.horaInicio, horaInicio) || other.horaInicio == horaInicio)&&(identical(other.duracionMin, duracionMin) || other.duracionMin == duracionMin)&&(identical(other.aforoMaximo, aforoMaximo) || other.aforoMaximo == aforoMaximo)&&(identical(other.activo, activo) || other.activo == activo));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,academiaId,profesorId,profesorNombre,titulo,descripcion,diaSemana,horaInicio,duracionMin,aforoMaximo,activo);

@override
String toString() {
  return 'PlantillaClase(id: $id, academiaId: $academiaId, profesorId: $profesorId, profesorNombre: $profesorNombre, titulo: $titulo, descripcion: $descripcion, diaSemana: $diaSemana, horaInicio: $horaInicio, duracionMin: $duracionMin, aforoMaximo: $aforoMaximo, activo: $activo)';
}


}

/// @nodoc
abstract mixin class $PlantillaClaseCopyWith<$Res>  {
  factory $PlantillaClaseCopyWith(PlantillaClase value, $Res Function(PlantillaClase) _then) = _$PlantillaClaseCopyWithImpl;
@useResult
$Res call({
 String id,@JsonKey(name: 'academia_id') String academiaId,@JsonKey(name: 'profesor_id') String profesorId,@JsonKey(name: 'profesor_nombre') String profesorNombre, String titulo, String? descripcion,@JsonKey(name: 'dia_semana') int diaSemana,@JsonKey(name: 'hora_inicio') String horaInicio,@JsonKey(name: 'duracion_min') int duracionMin,@JsonKey(name: 'aforo_maximo') int aforoMaximo, bool activo
});




}
/// @nodoc
class _$PlantillaClaseCopyWithImpl<$Res>
    implements $PlantillaClaseCopyWith<$Res> {
  _$PlantillaClaseCopyWithImpl(this._self, this._then);

  final PlantillaClase _self;
  final $Res Function(PlantillaClase) _then;

/// Create a copy of PlantillaClase
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? academiaId = null,Object? profesorId = null,Object? profesorNombre = null,Object? titulo = null,Object? descripcion = freezed,Object? diaSemana = null,Object? horaInicio = null,Object? duracionMin = null,Object? aforoMaximo = null,Object? activo = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,academiaId: null == academiaId ? _self.academiaId : academiaId // ignore: cast_nullable_to_non_nullable
as String,profesorId: null == profesorId ? _self.profesorId : profesorId // ignore: cast_nullable_to_non_nullable
as String,profesorNombre: null == profesorNombre ? _self.profesorNombre : profesorNombre // ignore: cast_nullable_to_non_nullable
as String,titulo: null == titulo ? _self.titulo : titulo // ignore: cast_nullable_to_non_nullable
as String,descripcion: freezed == descripcion ? _self.descripcion : descripcion // ignore: cast_nullable_to_non_nullable
as String?,diaSemana: null == diaSemana ? _self.diaSemana : diaSemana // ignore: cast_nullable_to_non_nullable
as int,horaInicio: null == horaInicio ? _self.horaInicio : horaInicio // ignore: cast_nullable_to_non_nullable
as String,duracionMin: null == duracionMin ? _self.duracionMin : duracionMin // ignore: cast_nullable_to_non_nullable
as int,aforoMaximo: null == aforoMaximo ? _self.aforoMaximo : aforoMaximo // ignore: cast_nullable_to_non_nullable
as int,activo: null == activo ? _self.activo : activo // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [PlantillaClase].
extension PlantillaClasePatterns on PlantillaClase {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PlantillaClase value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PlantillaClase() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PlantillaClase value)  $default,){
final _that = this;
switch (_that) {
case _PlantillaClase():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PlantillaClase value)?  $default,){
final _that = this;
switch (_that) {
case _PlantillaClase() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'academia_id')  String academiaId, @JsonKey(name: 'profesor_id')  String profesorId, @JsonKey(name: 'profesor_nombre')  String profesorNombre,  String titulo,  String? descripcion, @JsonKey(name: 'dia_semana')  int diaSemana, @JsonKey(name: 'hora_inicio')  String horaInicio, @JsonKey(name: 'duracion_min')  int duracionMin, @JsonKey(name: 'aforo_maximo')  int aforoMaximo,  bool activo)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PlantillaClase() when $default != null:
return $default(_that.id,_that.academiaId,_that.profesorId,_that.profesorNombre,_that.titulo,_that.descripcion,_that.diaSemana,_that.horaInicio,_that.duracionMin,_that.aforoMaximo,_that.activo);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'academia_id')  String academiaId, @JsonKey(name: 'profesor_id')  String profesorId, @JsonKey(name: 'profesor_nombre')  String profesorNombre,  String titulo,  String? descripcion, @JsonKey(name: 'dia_semana')  int diaSemana, @JsonKey(name: 'hora_inicio')  String horaInicio, @JsonKey(name: 'duracion_min')  int duracionMin, @JsonKey(name: 'aforo_maximo')  int aforoMaximo,  bool activo)  $default,) {final _that = this;
switch (_that) {
case _PlantillaClase():
return $default(_that.id,_that.academiaId,_that.profesorId,_that.profesorNombre,_that.titulo,_that.descripcion,_that.diaSemana,_that.horaInicio,_that.duracionMin,_that.aforoMaximo,_that.activo);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id, @JsonKey(name: 'academia_id')  String academiaId, @JsonKey(name: 'profesor_id')  String profesorId, @JsonKey(name: 'profesor_nombre')  String profesorNombre,  String titulo,  String? descripcion, @JsonKey(name: 'dia_semana')  int diaSemana, @JsonKey(name: 'hora_inicio')  String horaInicio, @JsonKey(name: 'duracion_min')  int duracionMin, @JsonKey(name: 'aforo_maximo')  int aforoMaximo,  bool activo)?  $default,) {final _that = this;
switch (_that) {
case _PlantillaClase() when $default != null:
return $default(_that.id,_that.academiaId,_that.profesorId,_that.profesorNombre,_that.titulo,_that.descripcion,_that.diaSemana,_that.horaInicio,_that.duracionMin,_that.aforoMaximo,_that.activo);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PlantillaClase implements PlantillaClase {
  const _PlantillaClase({required this.id, @JsonKey(name: 'academia_id') required this.academiaId, @JsonKey(name: 'profesor_id') required this.profesorId, @JsonKey(name: 'profesor_nombre') required this.profesorNombre, required this.titulo, this.descripcion, @JsonKey(name: 'dia_semana') required this.diaSemana, @JsonKey(name: 'hora_inicio') required this.horaInicio, @JsonKey(name: 'duracion_min') required this.duracionMin, @JsonKey(name: 'aforo_maximo') required this.aforoMaximo, required this.activo});
  factory _PlantillaClase.fromJson(Map<String, dynamic> json) => _$PlantillaClaseFromJson(json);

@override final  String id;
@override@JsonKey(name: 'academia_id') final  String academiaId;
@override@JsonKey(name: 'profesor_id') final  String profesorId;
@override@JsonKey(name: 'profesor_nombre') final  String profesorNombre;
@override final  String titulo;
@override final  String? descripcion;
/// 0 = domingo … 6 = sábado, igual que `extract(dow from …)` en
/// Postgres — así se guarda tal cual, sin traducir en ningún sitio.
@override@JsonKey(name: 'dia_semana') final  int diaSemana;
/// 'HH:mm', hora local de la academia.
@override@JsonKey(name: 'hora_inicio') final  String horaInicio;
@override@JsonKey(name: 'duracion_min') final  int duracionMin;
@override@JsonKey(name: 'aforo_maximo') final  int aforoMaximo;
@override final  bool activo;

/// Create a copy of PlantillaClase
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PlantillaClaseCopyWith<_PlantillaClase> get copyWith => __$PlantillaClaseCopyWithImpl<_PlantillaClase>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PlantillaClaseToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PlantillaClase&&(identical(other.id, id) || other.id == id)&&(identical(other.academiaId, academiaId) || other.academiaId == academiaId)&&(identical(other.profesorId, profesorId) || other.profesorId == profesorId)&&(identical(other.profesorNombre, profesorNombre) || other.profesorNombre == profesorNombre)&&(identical(other.titulo, titulo) || other.titulo == titulo)&&(identical(other.descripcion, descripcion) || other.descripcion == descripcion)&&(identical(other.diaSemana, diaSemana) || other.diaSemana == diaSemana)&&(identical(other.horaInicio, horaInicio) || other.horaInicio == horaInicio)&&(identical(other.duracionMin, duracionMin) || other.duracionMin == duracionMin)&&(identical(other.aforoMaximo, aforoMaximo) || other.aforoMaximo == aforoMaximo)&&(identical(other.activo, activo) || other.activo == activo));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,academiaId,profesorId,profesorNombre,titulo,descripcion,diaSemana,horaInicio,duracionMin,aforoMaximo,activo);

@override
String toString() {
  return 'PlantillaClase(id: $id, academiaId: $academiaId, profesorId: $profesorId, profesorNombre: $profesorNombre, titulo: $titulo, descripcion: $descripcion, diaSemana: $diaSemana, horaInicio: $horaInicio, duracionMin: $duracionMin, aforoMaximo: $aforoMaximo, activo: $activo)';
}


}

/// @nodoc
abstract mixin class _$PlantillaClaseCopyWith<$Res> implements $PlantillaClaseCopyWith<$Res> {
  factory _$PlantillaClaseCopyWith(_PlantillaClase value, $Res Function(_PlantillaClase) _then) = __$PlantillaClaseCopyWithImpl;
@override @useResult
$Res call({
 String id,@JsonKey(name: 'academia_id') String academiaId,@JsonKey(name: 'profesor_id') String profesorId,@JsonKey(name: 'profesor_nombre') String profesorNombre, String titulo, String? descripcion,@JsonKey(name: 'dia_semana') int diaSemana,@JsonKey(name: 'hora_inicio') String horaInicio,@JsonKey(name: 'duracion_min') int duracionMin,@JsonKey(name: 'aforo_maximo') int aforoMaximo, bool activo
});




}
/// @nodoc
class __$PlantillaClaseCopyWithImpl<$Res>
    implements _$PlantillaClaseCopyWith<$Res> {
  __$PlantillaClaseCopyWithImpl(this._self, this._then);

  final _PlantillaClase _self;
  final $Res Function(_PlantillaClase) _then;

/// Create a copy of PlantillaClase
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? academiaId = null,Object? profesorId = null,Object? profesorNombre = null,Object? titulo = null,Object? descripcion = freezed,Object? diaSemana = null,Object? horaInicio = null,Object? duracionMin = null,Object? aforoMaximo = null,Object? activo = null,}) {
  return _then(_PlantillaClase(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,academiaId: null == academiaId ? _self.academiaId : academiaId // ignore: cast_nullable_to_non_nullable
as String,profesorId: null == profesorId ? _self.profesorId : profesorId // ignore: cast_nullable_to_non_nullable
as String,profesorNombre: null == profesorNombre ? _self.profesorNombre : profesorNombre // ignore: cast_nullable_to_non_nullable
as String,titulo: null == titulo ? _self.titulo : titulo // ignore: cast_nullable_to_non_nullable
as String,descripcion: freezed == descripcion ? _self.descripcion : descripcion // ignore: cast_nullable_to_non_nullable
as String?,diaSemana: null == diaSemana ? _self.diaSemana : diaSemana // ignore: cast_nullable_to_non_nullable
as int,horaInicio: null == horaInicio ? _self.horaInicio : horaInicio // ignore: cast_nullable_to_non_nullable
as String,duracionMin: null == duracionMin ? _self.duracionMin : duracionMin // ignore: cast_nullable_to_non_nullable
as int,aforoMaximo: null == aforoMaximo ? _self.aforoMaximo : aforoMaximo // ignore: cast_nullable_to_non_nullable
as int,activo: null == activo ? _self.activo : activo // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
