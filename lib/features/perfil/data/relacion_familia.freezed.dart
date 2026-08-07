// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'relacion_familia.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$RelacionFamilia {

 String get id;@JsonKey(name: 'parent_id') String get parentId;@JsonKey(name: 'child_id') String get childId;@JsonKey(name: 'tipo_relacion') String get tipoRelacion;@JsonKey(name: 'created_at') DateTime get createdAt;
/// Create a copy of RelacionFamilia
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RelacionFamiliaCopyWith<RelacionFamilia> get copyWith => _$RelacionFamiliaCopyWithImpl<RelacionFamilia>(this as RelacionFamilia, _$identity);

  /// Serializes this RelacionFamilia to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RelacionFamilia&&(identical(other.id, id) || other.id == id)&&(identical(other.parentId, parentId) || other.parentId == parentId)&&(identical(other.childId, childId) || other.childId == childId)&&(identical(other.tipoRelacion, tipoRelacion) || other.tipoRelacion == tipoRelacion)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,parentId,childId,tipoRelacion,createdAt);

@override
String toString() {
  return 'RelacionFamilia(id: $id, parentId: $parentId, childId: $childId, tipoRelacion: $tipoRelacion, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class $RelacionFamiliaCopyWith<$Res>  {
  factory $RelacionFamiliaCopyWith(RelacionFamilia value, $Res Function(RelacionFamilia) _then) = _$RelacionFamiliaCopyWithImpl;
@useResult
$Res call({
 String id,@JsonKey(name: 'parent_id') String parentId,@JsonKey(name: 'child_id') String childId,@JsonKey(name: 'tipo_relacion') String tipoRelacion,@JsonKey(name: 'created_at') DateTime createdAt
});




}
/// @nodoc
class _$RelacionFamiliaCopyWithImpl<$Res>
    implements $RelacionFamiliaCopyWith<$Res> {
  _$RelacionFamiliaCopyWithImpl(this._self, this._then);

  final RelacionFamilia _self;
  final $Res Function(RelacionFamilia) _then;

/// Create a copy of RelacionFamilia
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? parentId = null,Object? childId = null,Object? tipoRelacion = null,Object? createdAt = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,parentId: null == parentId ? _self.parentId : parentId // ignore: cast_nullable_to_non_nullable
as String,childId: null == childId ? _self.childId : childId // ignore: cast_nullable_to_non_nullable
as String,tipoRelacion: null == tipoRelacion ? _self.tipoRelacion : tipoRelacion // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [RelacionFamilia].
extension RelacionFamiliaPatterns on RelacionFamilia {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RelacionFamilia value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RelacionFamilia() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RelacionFamilia value)  $default,){
final _that = this;
switch (_that) {
case _RelacionFamilia():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RelacionFamilia value)?  $default,){
final _that = this;
switch (_that) {
case _RelacionFamilia() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'parent_id')  String parentId, @JsonKey(name: 'child_id')  String childId, @JsonKey(name: 'tipo_relacion')  String tipoRelacion, @JsonKey(name: 'created_at')  DateTime createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RelacionFamilia() when $default != null:
return $default(_that.id,_that.parentId,_that.childId,_that.tipoRelacion,_that.createdAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'parent_id')  String parentId, @JsonKey(name: 'child_id')  String childId, @JsonKey(name: 'tipo_relacion')  String tipoRelacion, @JsonKey(name: 'created_at')  DateTime createdAt)  $default,) {final _that = this;
switch (_that) {
case _RelacionFamilia():
return $default(_that.id,_that.parentId,_that.childId,_that.tipoRelacion,_that.createdAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id, @JsonKey(name: 'parent_id')  String parentId, @JsonKey(name: 'child_id')  String childId, @JsonKey(name: 'tipo_relacion')  String tipoRelacion, @JsonKey(name: 'created_at')  DateTime createdAt)?  $default,) {final _that = this;
switch (_that) {
case _RelacionFamilia() when $default != null:
return $default(_that.id,_that.parentId,_that.childId,_that.tipoRelacion,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _RelacionFamilia implements RelacionFamilia {
  const _RelacionFamilia({required this.id, @JsonKey(name: 'parent_id') required this.parentId, @JsonKey(name: 'child_id') required this.childId, @JsonKey(name: 'tipo_relacion') required this.tipoRelacion, @JsonKey(name: 'created_at') required this.createdAt});
  factory _RelacionFamilia.fromJson(Map<String, dynamic> json) => _$RelacionFamiliaFromJson(json);

@override final  String id;
@override@JsonKey(name: 'parent_id') final  String parentId;
@override@JsonKey(name: 'child_id') final  String childId;
@override@JsonKey(name: 'tipo_relacion') final  String tipoRelacion;
@override@JsonKey(name: 'created_at') final  DateTime createdAt;

/// Create a copy of RelacionFamilia
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RelacionFamiliaCopyWith<_RelacionFamilia> get copyWith => __$RelacionFamiliaCopyWithImpl<_RelacionFamilia>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RelacionFamiliaToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _RelacionFamilia&&(identical(other.id, id) || other.id == id)&&(identical(other.parentId, parentId) || other.parentId == parentId)&&(identical(other.childId, childId) || other.childId == childId)&&(identical(other.tipoRelacion, tipoRelacion) || other.tipoRelacion == tipoRelacion)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,parentId,childId,tipoRelacion,createdAt);

@override
String toString() {
  return 'RelacionFamilia(id: $id, parentId: $parentId, childId: $childId, tipoRelacion: $tipoRelacion, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$RelacionFamiliaCopyWith<$Res> implements $RelacionFamiliaCopyWith<$Res> {
  factory _$RelacionFamiliaCopyWith(_RelacionFamilia value, $Res Function(_RelacionFamilia) _then) = __$RelacionFamiliaCopyWithImpl;
@override @useResult
$Res call({
 String id,@JsonKey(name: 'parent_id') String parentId,@JsonKey(name: 'child_id') String childId,@JsonKey(name: 'tipo_relacion') String tipoRelacion,@JsonKey(name: 'created_at') DateTime createdAt
});




}
/// @nodoc
class __$RelacionFamiliaCopyWithImpl<$Res>
    implements _$RelacionFamiliaCopyWith<$Res> {
  __$RelacionFamiliaCopyWithImpl(this._self, this._then);

  final _RelacionFamilia _self;
  final $Res Function(_RelacionFamilia) _then;

/// Create a copy of RelacionFamilia
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? parentId = null,Object? childId = null,Object? tipoRelacion = null,Object? createdAt = null,}) {
  return _then(_RelacionFamilia(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,parentId: null == parentId ? _self.parentId : parentId // ignore: cast_nullable_to_non_nullable
as String,childId: null == childId ? _self.childId : childId // ignore: cast_nullable_to_non_nullable
as String,tipoRelacion: null == tipoRelacion ? _self.tipoRelacion : tipoRelacion // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

// dart format on
