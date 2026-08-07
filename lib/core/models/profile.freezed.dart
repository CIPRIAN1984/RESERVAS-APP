// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'profile.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Profile {

 String get id;@JsonKey(name: 'academia_id') String? get academiaId; String get rol; String get nombre; String? get apellidos;@JsonKey(name: 'foto_url') String? get fotoUrl; String? get cinturon; String get estado;@JsonKey(name: 'parent_id') String? get parentId;
/// Create a copy of Profile
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProfileCopyWith<Profile> get copyWith => _$ProfileCopyWithImpl<Profile>(this as Profile, _$identity);

  /// Serializes this Profile to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Profile&&(identical(other.id, id) || other.id == id)&&(identical(other.academiaId, academiaId) || other.academiaId == academiaId)&&(identical(other.rol, rol) || other.rol == rol)&&(identical(other.nombre, nombre) || other.nombre == nombre)&&(identical(other.apellidos, apellidos) || other.apellidos == apellidos)&&(identical(other.fotoUrl, fotoUrl) || other.fotoUrl == fotoUrl)&&(identical(other.cinturon, cinturon) || other.cinturon == cinturon)&&(identical(other.estado, estado) || other.estado == estado)&&(identical(other.parentId, parentId) || other.parentId == parentId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,academiaId,rol,nombre,apellidos,fotoUrl,cinturon,estado,parentId);

@override
String toString() {
  return 'Profile(id: $id, academiaId: $academiaId, rol: $rol, nombre: $nombre, apellidos: $apellidos, fotoUrl: $fotoUrl, cinturon: $cinturon, estado: $estado, parentId: $parentId)';
}


}

/// @nodoc
abstract mixin class $ProfileCopyWith<$Res>  {
  factory $ProfileCopyWith(Profile value, $Res Function(Profile) _then) = _$ProfileCopyWithImpl;
@useResult
$Res call({
 String id,@JsonKey(name: 'academia_id') String? academiaId, String rol, String nombre, String? apellidos,@JsonKey(name: 'foto_url') String? fotoUrl, String? cinturon, String estado,@JsonKey(name: 'parent_id') String? parentId
});




}
/// @nodoc
class _$ProfileCopyWithImpl<$Res>
    implements $ProfileCopyWith<$Res> {
  _$ProfileCopyWithImpl(this._self, this._then);

  final Profile _self;
  final $Res Function(Profile) _then;

/// Create a copy of Profile
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? academiaId = freezed,Object? rol = null,Object? nombre = null,Object? apellidos = freezed,Object? fotoUrl = freezed,Object? cinturon = freezed,Object? estado = null,Object? parentId = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,academiaId: freezed == academiaId ? _self.academiaId : academiaId // ignore: cast_nullable_to_non_nullable
as String?,rol: null == rol ? _self.rol : rol // ignore: cast_nullable_to_non_nullable
as String,nombre: null == nombre ? _self.nombre : nombre // ignore: cast_nullable_to_non_nullable
as String,apellidos: freezed == apellidos ? _self.apellidos : apellidos // ignore: cast_nullable_to_non_nullable
as String?,fotoUrl: freezed == fotoUrl ? _self.fotoUrl : fotoUrl // ignore: cast_nullable_to_non_nullable
as String?,cinturon: freezed == cinturon ? _self.cinturon : cinturon // ignore: cast_nullable_to_non_nullable
as String?,estado: null == estado ? _self.estado : estado // ignore: cast_nullable_to_non_nullable
as String,parentId: freezed == parentId ? _self.parentId : parentId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [Profile].
extension ProfilePatterns on Profile {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Profile value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Profile() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Profile value)  $default,){
final _that = this;
switch (_that) {
case _Profile():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Profile value)?  $default,){
final _that = this;
switch (_that) {
case _Profile() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'academia_id')  String? academiaId,  String rol,  String nombre,  String? apellidos, @JsonKey(name: 'foto_url')  String? fotoUrl,  String? cinturon,  String estado, @JsonKey(name: 'parent_id')  String? parentId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Profile() when $default != null:
return $default(_that.id,_that.academiaId,_that.rol,_that.nombre,_that.apellidos,_that.fotoUrl,_that.cinturon,_that.estado,_that.parentId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'academia_id')  String? academiaId,  String rol,  String nombre,  String? apellidos, @JsonKey(name: 'foto_url')  String? fotoUrl,  String? cinturon,  String estado, @JsonKey(name: 'parent_id')  String? parentId)  $default,) {final _that = this;
switch (_that) {
case _Profile():
return $default(_that.id,_that.academiaId,_that.rol,_that.nombre,_that.apellidos,_that.fotoUrl,_that.cinturon,_that.estado,_that.parentId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id, @JsonKey(name: 'academia_id')  String? academiaId,  String rol,  String nombre,  String? apellidos, @JsonKey(name: 'foto_url')  String? fotoUrl,  String? cinturon,  String estado, @JsonKey(name: 'parent_id')  String? parentId)?  $default,) {final _that = this;
switch (_that) {
case _Profile() when $default != null:
return $default(_that.id,_that.academiaId,_that.rol,_that.nombre,_that.apellidos,_that.fotoUrl,_that.cinturon,_that.estado,_that.parentId);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Profile extends Profile {
  const _Profile({required this.id, @JsonKey(name: 'academia_id') this.academiaId, required this.rol, required this.nombre, this.apellidos, @JsonKey(name: 'foto_url') this.fotoUrl, this.cinturon, required this.estado, @JsonKey(name: 'parent_id') this.parentId}): super._();
  factory _Profile.fromJson(Map<String, dynamic> json) => _$ProfileFromJson(json);

@override final  String id;
@override@JsonKey(name: 'academia_id') final  String? academiaId;
@override final  String rol;
@override final  String nombre;
@override final  String? apellidos;
@override@JsonKey(name: 'foto_url') final  String? fotoUrl;
@override final  String? cinturon;
@override final  String estado;
@override@JsonKey(name: 'parent_id') final  String? parentId;

/// Create a copy of Profile
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProfileCopyWith<_Profile> get copyWith => __$ProfileCopyWithImpl<_Profile>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ProfileToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Profile&&(identical(other.id, id) || other.id == id)&&(identical(other.academiaId, academiaId) || other.academiaId == academiaId)&&(identical(other.rol, rol) || other.rol == rol)&&(identical(other.nombre, nombre) || other.nombre == nombre)&&(identical(other.apellidos, apellidos) || other.apellidos == apellidos)&&(identical(other.fotoUrl, fotoUrl) || other.fotoUrl == fotoUrl)&&(identical(other.cinturon, cinturon) || other.cinturon == cinturon)&&(identical(other.estado, estado) || other.estado == estado)&&(identical(other.parentId, parentId) || other.parentId == parentId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,academiaId,rol,nombre,apellidos,fotoUrl,cinturon,estado,parentId);

@override
String toString() {
  return 'Profile(id: $id, academiaId: $academiaId, rol: $rol, nombre: $nombre, apellidos: $apellidos, fotoUrl: $fotoUrl, cinturon: $cinturon, estado: $estado, parentId: $parentId)';
}


}

/// @nodoc
abstract mixin class _$ProfileCopyWith<$Res> implements $ProfileCopyWith<$Res> {
  factory _$ProfileCopyWith(_Profile value, $Res Function(_Profile) _then) = __$ProfileCopyWithImpl;
@override @useResult
$Res call({
 String id,@JsonKey(name: 'academia_id') String? academiaId, String rol, String nombre, String? apellidos,@JsonKey(name: 'foto_url') String? fotoUrl, String? cinturon, String estado,@JsonKey(name: 'parent_id') String? parentId
});




}
/// @nodoc
class __$ProfileCopyWithImpl<$Res>
    implements _$ProfileCopyWith<$Res> {
  __$ProfileCopyWithImpl(this._self, this._then);

  final _Profile _self;
  final $Res Function(_Profile) _then;

/// Create a copy of Profile
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? academiaId = freezed,Object? rol = null,Object? nombre = null,Object? apellidos = freezed,Object? fotoUrl = freezed,Object? cinturon = freezed,Object? estado = null,Object? parentId = freezed,}) {
  return _then(_Profile(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,academiaId: freezed == academiaId ? _self.academiaId : academiaId // ignore: cast_nullable_to_non_nullable
as String?,rol: null == rol ? _self.rol : rol // ignore: cast_nullable_to_non_nullable
as String,nombre: null == nombre ? _self.nombre : nombre // ignore: cast_nullable_to_non_nullable
as String,apellidos: freezed == apellidos ? _self.apellidos : apellidos // ignore: cast_nullable_to_non_nullable
as String?,fotoUrl: freezed == fotoUrl ? _self.fotoUrl : fotoUrl // ignore: cast_nullable_to_non_nullable
as String?,cinturon: freezed == cinturon ? _self.cinturon : cinturon // ignore: cast_nullable_to_non_nullable
as String?,estado: null == estado ? _self.estado : estado // ignore: cast_nullable_to_non_nullable
as String,parentId: freezed == parentId ? _self.parentId : parentId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
