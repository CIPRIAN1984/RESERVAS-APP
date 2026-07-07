// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'media_tecnica.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$MediaTecnica {

 String get id;@JsonKey(name: 'tecnica_id') String get tecnicaId; String get tipo; String get url;@JsonKey(name: 'subido_por') String get subidoPor;
/// Create a copy of MediaTecnica
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MediaTecnicaCopyWith<MediaTecnica> get copyWith => _$MediaTecnicaCopyWithImpl<MediaTecnica>(this as MediaTecnica, _$identity);

  /// Serializes this MediaTecnica to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MediaTecnica&&(identical(other.id, id) || other.id == id)&&(identical(other.tecnicaId, tecnicaId) || other.tecnicaId == tecnicaId)&&(identical(other.tipo, tipo) || other.tipo == tipo)&&(identical(other.url, url) || other.url == url)&&(identical(other.subidoPor, subidoPor) || other.subidoPor == subidoPor));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,tecnicaId,tipo,url,subidoPor);

@override
String toString() {
  return 'MediaTecnica(id: $id, tecnicaId: $tecnicaId, tipo: $tipo, url: $url, subidoPor: $subidoPor)';
}


}

/// @nodoc
abstract mixin class $MediaTecnicaCopyWith<$Res>  {
  factory $MediaTecnicaCopyWith(MediaTecnica value, $Res Function(MediaTecnica) _then) = _$MediaTecnicaCopyWithImpl;
@useResult
$Res call({
 String id,@JsonKey(name: 'tecnica_id') String tecnicaId, String tipo, String url,@JsonKey(name: 'subido_por') String subidoPor
});




}
/// @nodoc
class _$MediaTecnicaCopyWithImpl<$Res>
    implements $MediaTecnicaCopyWith<$Res> {
  _$MediaTecnicaCopyWithImpl(this._self, this._then);

  final MediaTecnica _self;
  final $Res Function(MediaTecnica) _then;

/// Create a copy of MediaTecnica
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? tecnicaId = null,Object? tipo = null,Object? url = null,Object? subidoPor = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,tecnicaId: null == tecnicaId ? _self.tecnicaId : tecnicaId // ignore: cast_nullable_to_non_nullable
as String,tipo: null == tipo ? _self.tipo : tipo // ignore: cast_nullable_to_non_nullable
as String,url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,subidoPor: null == subidoPor ? _self.subidoPor : subidoPor // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [MediaTecnica].
extension MediaTecnicaPatterns on MediaTecnica {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MediaTecnica value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MediaTecnica() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MediaTecnica value)  $default,){
final _that = this;
switch (_that) {
case _MediaTecnica():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MediaTecnica value)?  $default,){
final _that = this;
switch (_that) {
case _MediaTecnica() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'tecnica_id')  String tecnicaId,  String tipo,  String url, @JsonKey(name: 'subido_por')  String subidoPor)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MediaTecnica() when $default != null:
return $default(_that.id,_that.tecnicaId,_that.tipo,_that.url,_that.subidoPor);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'tecnica_id')  String tecnicaId,  String tipo,  String url, @JsonKey(name: 'subido_por')  String subidoPor)  $default,) {final _that = this;
switch (_that) {
case _MediaTecnica():
return $default(_that.id,_that.tecnicaId,_that.tipo,_that.url,_that.subidoPor);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id, @JsonKey(name: 'tecnica_id')  String tecnicaId,  String tipo,  String url, @JsonKey(name: 'subido_por')  String subidoPor)?  $default,) {final _that = this;
switch (_that) {
case _MediaTecnica() when $default != null:
return $default(_that.id,_that.tecnicaId,_that.tipo,_that.url,_that.subidoPor);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _MediaTecnica implements MediaTecnica {
  const _MediaTecnica({required this.id, @JsonKey(name: 'tecnica_id') required this.tecnicaId, required this.tipo, required this.url, @JsonKey(name: 'subido_por') required this.subidoPor});
  factory _MediaTecnica.fromJson(Map<String, dynamic> json) => _$MediaTecnicaFromJson(json);

@override final  String id;
@override@JsonKey(name: 'tecnica_id') final  String tecnicaId;
@override final  String tipo;
@override final  String url;
@override@JsonKey(name: 'subido_por') final  String subidoPor;

/// Create a copy of MediaTecnica
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MediaTecnicaCopyWith<_MediaTecnica> get copyWith => __$MediaTecnicaCopyWithImpl<_MediaTecnica>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MediaTecnicaToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MediaTecnica&&(identical(other.id, id) || other.id == id)&&(identical(other.tecnicaId, tecnicaId) || other.tecnicaId == tecnicaId)&&(identical(other.tipo, tipo) || other.tipo == tipo)&&(identical(other.url, url) || other.url == url)&&(identical(other.subidoPor, subidoPor) || other.subidoPor == subidoPor));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,tecnicaId,tipo,url,subidoPor);

@override
String toString() {
  return 'MediaTecnica(id: $id, tecnicaId: $tecnicaId, tipo: $tipo, url: $url, subidoPor: $subidoPor)';
}


}

/// @nodoc
abstract mixin class _$MediaTecnicaCopyWith<$Res> implements $MediaTecnicaCopyWith<$Res> {
  factory _$MediaTecnicaCopyWith(_MediaTecnica value, $Res Function(_MediaTecnica) _then) = __$MediaTecnicaCopyWithImpl;
@override @useResult
$Res call({
 String id,@JsonKey(name: 'tecnica_id') String tecnicaId, String tipo, String url,@JsonKey(name: 'subido_por') String subidoPor
});




}
/// @nodoc
class __$MediaTecnicaCopyWithImpl<$Res>
    implements _$MediaTecnicaCopyWith<$Res> {
  __$MediaTecnicaCopyWithImpl(this._self, this._then);

  final _MediaTecnica _self;
  final $Res Function(_MediaTecnica) _then;

/// Create a copy of MediaTecnica
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? tecnicaId = null,Object? tipo = null,Object? url = null,Object? subidoPor = null,}) {
  return _then(_MediaTecnica(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,tecnicaId: null == tecnicaId ? _self.tecnicaId : tecnicaId // ignore: cast_nullable_to_non_nullable
as String,tipo: null == tipo ? _self.tipo : tipo // ignore: cast_nullable_to_non_nullable
as String,url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,subidoPor: null == subidoPor ? _self.subidoPor : subidoPor // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
