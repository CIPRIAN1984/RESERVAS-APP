// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'saldo_clases.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$SaldoClases {

 bool get tieneCuota; bool get ilimitada; String? get tarifaNombre; int? get incluidas; int? get gastadas; int? get reservadas; int? get disponibles;
/// Create a copy of SaldoClases
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SaldoClasesCopyWith<SaldoClases> get copyWith => _$SaldoClasesCopyWithImpl<SaldoClases>(this as SaldoClases, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SaldoClases&&(identical(other.tieneCuota, tieneCuota) || other.tieneCuota == tieneCuota)&&(identical(other.ilimitada, ilimitada) || other.ilimitada == ilimitada)&&(identical(other.tarifaNombre, tarifaNombre) || other.tarifaNombre == tarifaNombre)&&(identical(other.incluidas, incluidas) || other.incluidas == incluidas)&&(identical(other.gastadas, gastadas) || other.gastadas == gastadas)&&(identical(other.reservadas, reservadas) || other.reservadas == reservadas)&&(identical(other.disponibles, disponibles) || other.disponibles == disponibles));
}


@override
int get hashCode => Object.hash(runtimeType,tieneCuota,ilimitada,tarifaNombre,incluidas,gastadas,reservadas,disponibles);

@override
String toString() {
  return 'SaldoClases(tieneCuota: $tieneCuota, ilimitada: $ilimitada, tarifaNombre: $tarifaNombre, incluidas: $incluidas, gastadas: $gastadas, reservadas: $reservadas, disponibles: $disponibles)';
}


}

/// @nodoc
abstract mixin class $SaldoClasesCopyWith<$Res>  {
  factory $SaldoClasesCopyWith(SaldoClases value, $Res Function(SaldoClases) _then) = _$SaldoClasesCopyWithImpl;
@useResult
$Res call({
 bool tieneCuota, bool ilimitada, String? tarifaNombre, int? incluidas, int? gastadas, int? reservadas, int? disponibles
});




}
/// @nodoc
class _$SaldoClasesCopyWithImpl<$Res>
    implements $SaldoClasesCopyWith<$Res> {
  _$SaldoClasesCopyWithImpl(this._self, this._then);

  final SaldoClases _self;
  final $Res Function(SaldoClases) _then;

/// Create a copy of SaldoClases
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? tieneCuota = null,Object? ilimitada = null,Object? tarifaNombre = freezed,Object? incluidas = freezed,Object? gastadas = freezed,Object? reservadas = freezed,Object? disponibles = freezed,}) {
  return _then(_self.copyWith(
tieneCuota: null == tieneCuota ? _self.tieneCuota : tieneCuota // ignore: cast_nullable_to_non_nullable
as bool,ilimitada: null == ilimitada ? _self.ilimitada : ilimitada // ignore: cast_nullable_to_non_nullable
as bool,tarifaNombre: freezed == tarifaNombre ? _self.tarifaNombre : tarifaNombre // ignore: cast_nullable_to_non_nullable
as String?,incluidas: freezed == incluidas ? _self.incluidas : incluidas // ignore: cast_nullable_to_non_nullable
as int?,gastadas: freezed == gastadas ? _self.gastadas : gastadas // ignore: cast_nullable_to_non_nullable
as int?,reservadas: freezed == reservadas ? _self.reservadas : reservadas // ignore: cast_nullable_to_non_nullable
as int?,disponibles: freezed == disponibles ? _self.disponibles : disponibles // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [SaldoClases].
extension SaldoClasesPatterns on SaldoClases {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SaldoClases value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SaldoClases() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SaldoClases value)  $default,){
final _that = this;
switch (_that) {
case _SaldoClases():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SaldoClases value)?  $default,){
final _that = this;
switch (_that) {
case _SaldoClases() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool tieneCuota,  bool ilimitada,  String? tarifaNombre,  int? incluidas,  int? gastadas,  int? reservadas,  int? disponibles)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SaldoClases() when $default != null:
return $default(_that.tieneCuota,_that.ilimitada,_that.tarifaNombre,_that.incluidas,_that.gastadas,_that.reservadas,_that.disponibles);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool tieneCuota,  bool ilimitada,  String? tarifaNombre,  int? incluidas,  int? gastadas,  int? reservadas,  int? disponibles)  $default,) {final _that = this;
switch (_that) {
case _SaldoClases():
return $default(_that.tieneCuota,_that.ilimitada,_that.tarifaNombre,_that.incluidas,_that.gastadas,_that.reservadas,_that.disponibles);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool tieneCuota,  bool ilimitada,  String? tarifaNombre,  int? incluidas,  int? gastadas,  int? reservadas,  int? disponibles)?  $default,) {final _that = this;
switch (_that) {
case _SaldoClases() when $default != null:
return $default(_that.tieneCuota,_that.ilimitada,_that.tarifaNombre,_that.incluidas,_that.gastadas,_that.reservadas,_that.disponibles);case _:
  return null;

}
}

}

/// @nodoc


class _SaldoClases implements SaldoClases {
  const _SaldoClases({required this.tieneCuota, required this.ilimitada, this.tarifaNombre, this.incluidas, this.gastadas, this.reservadas, this.disponibles});
  

@override final  bool tieneCuota;
@override final  bool ilimitada;
@override final  String? tarifaNombre;
@override final  int? incluidas;
@override final  int? gastadas;
@override final  int? reservadas;
@override final  int? disponibles;

/// Create a copy of SaldoClases
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SaldoClasesCopyWith<_SaldoClases> get copyWith => __$SaldoClasesCopyWithImpl<_SaldoClases>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SaldoClases&&(identical(other.tieneCuota, tieneCuota) || other.tieneCuota == tieneCuota)&&(identical(other.ilimitada, ilimitada) || other.ilimitada == ilimitada)&&(identical(other.tarifaNombre, tarifaNombre) || other.tarifaNombre == tarifaNombre)&&(identical(other.incluidas, incluidas) || other.incluidas == incluidas)&&(identical(other.gastadas, gastadas) || other.gastadas == gastadas)&&(identical(other.reservadas, reservadas) || other.reservadas == reservadas)&&(identical(other.disponibles, disponibles) || other.disponibles == disponibles));
}


@override
int get hashCode => Object.hash(runtimeType,tieneCuota,ilimitada,tarifaNombre,incluidas,gastadas,reservadas,disponibles);

@override
String toString() {
  return 'SaldoClases(tieneCuota: $tieneCuota, ilimitada: $ilimitada, tarifaNombre: $tarifaNombre, incluidas: $incluidas, gastadas: $gastadas, reservadas: $reservadas, disponibles: $disponibles)';
}


}

/// @nodoc
abstract mixin class _$SaldoClasesCopyWith<$Res> implements $SaldoClasesCopyWith<$Res> {
  factory _$SaldoClasesCopyWith(_SaldoClases value, $Res Function(_SaldoClases) _then) = __$SaldoClasesCopyWithImpl;
@override @useResult
$Res call({
 bool tieneCuota, bool ilimitada, String? tarifaNombre, int? incluidas, int? gastadas, int? reservadas, int? disponibles
});




}
/// @nodoc
class __$SaldoClasesCopyWithImpl<$Res>
    implements _$SaldoClasesCopyWith<$Res> {
  __$SaldoClasesCopyWithImpl(this._self, this._then);

  final _SaldoClases _self;
  final $Res Function(_SaldoClases) _then;

/// Create a copy of SaldoClases
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? tieneCuota = null,Object? ilimitada = null,Object? tarifaNombre = freezed,Object? incluidas = freezed,Object? gastadas = freezed,Object? reservadas = freezed,Object? disponibles = freezed,}) {
  return _then(_SaldoClases(
tieneCuota: null == tieneCuota ? _self.tieneCuota : tieneCuota // ignore: cast_nullable_to_non_nullable
as bool,ilimitada: null == ilimitada ? _self.ilimitada : ilimitada // ignore: cast_nullable_to_non_nullable
as bool,tarifaNombre: freezed == tarifaNombre ? _self.tarifaNombre : tarifaNombre // ignore: cast_nullable_to_non_nullable
as String?,incluidas: freezed == incluidas ? _self.incluidas : incluidas // ignore: cast_nullable_to_non_nullable
as int?,gastadas: freezed == gastadas ? _self.gastadas : gastadas // ignore: cast_nullable_to_non_nullable
as int?,reservadas: freezed == reservadas ? _self.reservadas : reservadas // ignore: cast_nullable_to_non_nullable
as int?,disponibles: freezed == disponibles ? _self.disponibles : disponibles // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}

// dart format on
