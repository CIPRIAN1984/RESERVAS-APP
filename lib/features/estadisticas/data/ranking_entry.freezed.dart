// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'ranking_entry.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$RankingEntry {

@JsonKey(name: 'alumno_id') String get alumnoId; String get nombre; String? get apellidos;@JsonKey(name: 'foto_url') String? get fotoUrl; String? get cinturon;@JsonKey(name: 'asistencias_count') int get asistenciasCount;
/// Create a copy of RankingEntry
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RankingEntryCopyWith<RankingEntry> get copyWith => _$RankingEntryCopyWithImpl<RankingEntry>(this as RankingEntry, _$identity);

  /// Serializes this RankingEntry to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RankingEntry&&(identical(other.alumnoId, alumnoId) || other.alumnoId == alumnoId)&&(identical(other.nombre, nombre) || other.nombre == nombre)&&(identical(other.apellidos, apellidos) || other.apellidos == apellidos)&&(identical(other.fotoUrl, fotoUrl) || other.fotoUrl == fotoUrl)&&(identical(other.cinturon, cinturon) || other.cinturon == cinturon)&&(identical(other.asistenciasCount, asistenciasCount) || other.asistenciasCount == asistenciasCount));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,alumnoId,nombre,apellidos,fotoUrl,cinturon,asistenciasCount);

@override
String toString() {
  return 'RankingEntry(alumnoId: $alumnoId, nombre: $nombre, apellidos: $apellidos, fotoUrl: $fotoUrl, cinturon: $cinturon, asistenciasCount: $asistenciasCount)';
}


}

/// @nodoc
abstract mixin class $RankingEntryCopyWith<$Res>  {
  factory $RankingEntryCopyWith(RankingEntry value, $Res Function(RankingEntry) _then) = _$RankingEntryCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'alumno_id') String alumnoId, String nombre, String? apellidos,@JsonKey(name: 'foto_url') String? fotoUrl, String? cinturon,@JsonKey(name: 'asistencias_count') int asistenciasCount
});




}
/// @nodoc
class _$RankingEntryCopyWithImpl<$Res>
    implements $RankingEntryCopyWith<$Res> {
  _$RankingEntryCopyWithImpl(this._self, this._then);

  final RankingEntry _self;
  final $Res Function(RankingEntry) _then;

/// Create a copy of RankingEntry
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? alumnoId = null,Object? nombre = null,Object? apellidos = freezed,Object? fotoUrl = freezed,Object? cinturon = freezed,Object? asistenciasCount = null,}) {
  return _then(_self.copyWith(
alumnoId: null == alumnoId ? _self.alumnoId : alumnoId // ignore: cast_nullable_to_non_nullable
as String,nombre: null == nombre ? _self.nombre : nombre // ignore: cast_nullable_to_non_nullable
as String,apellidos: freezed == apellidos ? _self.apellidos : apellidos // ignore: cast_nullable_to_non_nullable
as String?,fotoUrl: freezed == fotoUrl ? _self.fotoUrl : fotoUrl // ignore: cast_nullable_to_non_nullable
as String?,cinturon: freezed == cinturon ? _self.cinturon : cinturon // ignore: cast_nullable_to_non_nullable
as String?,asistenciasCount: null == asistenciasCount ? _self.asistenciasCount : asistenciasCount // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [RankingEntry].
extension RankingEntryPatterns on RankingEntry {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RankingEntry value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RankingEntry() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RankingEntry value)  $default,){
final _that = this;
switch (_that) {
case _RankingEntry():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RankingEntry value)?  $default,){
final _that = this;
switch (_that) {
case _RankingEntry() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'alumno_id')  String alumnoId,  String nombre,  String? apellidos, @JsonKey(name: 'foto_url')  String? fotoUrl,  String? cinturon, @JsonKey(name: 'asistencias_count')  int asistenciasCount)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RankingEntry() when $default != null:
return $default(_that.alumnoId,_that.nombre,_that.apellidos,_that.fotoUrl,_that.cinturon,_that.asistenciasCount);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'alumno_id')  String alumnoId,  String nombre,  String? apellidos, @JsonKey(name: 'foto_url')  String? fotoUrl,  String? cinturon, @JsonKey(name: 'asistencias_count')  int asistenciasCount)  $default,) {final _that = this;
switch (_that) {
case _RankingEntry():
return $default(_that.alumnoId,_that.nombre,_that.apellidos,_that.fotoUrl,_that.cinturon,_that.asistenciasCount);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'alumno_id')  String alumnoId,  String nombre,  String? apellidos, @JsonKey(name: 'foto_url')  String? fotoUrl,  String? cinturon, @JsonKey(name: 'asistencias_count')  int asistenciasCount)?  $default,) {final _that = this;
switch (_that) {
case _RankingEntry() when $default != null:
return $default(_that.alumnoId,_that.nombre,_that.apellidos,_that.fotoUrl,_that.cinturon,_that.asistenciasCount);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _RankingEntry extends RankingEntry {
  const _RankingEntry({@JsonKey(name: 'alumno_id') required this.alumnoId, required this.nombre, this.apellidos, @JsonKey(name: 'foto_url') this.fotoUrl, this.cinturon, @JsonKey(name: 'asistencias_count') required this.asistenciasCount}): super._();
  factory _RankingEntry.fromJson(Map<String, dynamic> json) => _$RankingEntryFromJson(json);

@override@JsonKey(name: 'alumno_id') final  String alumnoId;
@override final  String nombre;
@override final  String? apellidos;
@override@JsonKey(name: 'foto_url') final  String? fotoUrl;
@override final  String? cinturon;
@override@JsonKey(name: 'asistencias_count') final  int asistenciasCount;

/// Create a copy of RankingEntry
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RankingEntryCopyWith<_RankingEntry> get copyWith => __$RankingEntryCopyWithImpl<_RankingEntry>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RankingEntryToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _RankingEntry&&(identical(other.alumnoId, alumnoId) || other.alumnoId == alumnoId)&&(identical(other.nombre, nombre) || other.nombre == nombre)&&(identical(other.apellidos, apellidos) || other.apellidos == apellidos)&&(identical(other.fotoUrl, fotoUrl) || other.fotoUrl == fotoUrl)&&(identical(other.cinturon, cinturon) || other.cinturon == cinturon)&&(identical(other.asistenciasCount, asistenciasCount) || other.asistenciasCount == asistenciasCount));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,alumnoId,nombre,apellidos,fotoUrl,cinturon,asistenciasCount);

@override
String toString() {
  return 'RankingEntry(alumnoId: $alumnoId, nombre: $nombre, apellidos: $apellidos, fotoUrl: $fotoUrl, cinturon: $cinturon, asistenciasCount: $asistenciasCount)';
}


}

/// @nodoc
abstract mixin class _$RankingEntryCopyWith<$Res> implements $RankingEntryCopyWith<$Res> {
  factory _$RankingEntryCopyWith(_RankingEntry value, $Res Function(_RankingEntry) _then) = __$RankingEntryCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'alumno_id') String alumnoId, String nombre, String? apellidos,@JsonKey(name: 'foto_url') String? fotoUrl, String? cinturon,@JsonKey(name: 'asistencias_count') int asistenciasCount
});




}
/// @nodoc
class __$RankingEntryCopyWithImpl<$Res>
    implements _$RankingEntryCopyWith<$Res> {
  __$RankingEntryCopyWithImpl(this._self, this._then);

  final _RankingEntry _self;
  final $Res Function(_RankingEntry) _then;

/// Create a copy of RankingEntry
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? alumnoId = null,Object? nombre = null,Object? apellidos = freezed,Object? fotoUrl = freezed,Object? cinturon = freezed,Object? asistenciasCount = null,}) {
  return _then(_RankingEntry(
alumnoId: null == alumnoId ? _self.alumnoId : alumnoId // ignore: cast_nullable_to_non_nullable
as String,nombre: null == nombre ? _self.nombre : nombre // ignore: cast_nullable_to_non_nullable
as String,apellidos: freezed == apellidos ? _self.apellidos : apellidos // ignore: cast_nullable_to_non_nullable
as String?,fotoUrl: freezed == fotoUrl ? _self.fotoUrl : fotoUrl // ignore: cast_nullable_to_non_nullable
as String?,cinturon: freezed == cinturon ? _self.cinturon : cinturon // ignore: cast_nullable_to_non_nullable
as String?,asistenciasCount: null == asistenciasCount ? _self.asistenciasCount : asistenciasCount // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
