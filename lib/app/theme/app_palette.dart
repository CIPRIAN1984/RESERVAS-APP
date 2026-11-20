import 'package:flutter/material.dart';

import 'color_tokens.dart';

/// Paleta de color que cambia con el modo (claro/oscuro). Es una extensión del
/// tema: las pantallas la leen con `context.paleta` y así se repintan solas al
/// cambiar de modo. Los cinturones **no** viven aquí: son el dato y no cambian.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.ground,
    required this.surface,
    required this.surfaceStrong,
    required this.line,
    required this.ink,
    required this.onInk,
    required this.inkBorder,
    required this.subtle,
    required this.disabled,
    required this.acid,
    required this.onAcid,
    required this.crown,
    required this.successBg,
    required this.successFg,
    required this.dangerBg,
    required this.dangerFg,
    required this.infoBg,
    required this.infoFg,
    required this.neutralBg,
    required this.neutralFg,
    required this.warningBg,
    required this.warningFg,
    required this.accentBg,
    required this.accentFg,
    required this.destructive,
  });

  final Color ground,
      surface,
      surfaceStrong,
      line,
      ink,
      onInk,
      inkBorder,
      subtle,
      disabled,
      acid,
      onAcid,
      crown,
      successBg,
      successFg,
      dangerBg,
      dangerFg,
      infoBg,
      infoFg,
      neutralBg,
      neutralFg,
      warningBg,
      warningFg,
      accentBg,
      accentFg,
      destructive;

  /// Modo claro: exactamente los tokens de siempre.
  static const light = AppPalette(
    ground: AppColors.ground,
    surface: AppColors.surface,
    surfaceStrong: AppColors.surfaceStrong,
    line: AppColors.line,
    ink: AppColors.ink,
    onInk: AppColors.onInk,
    inkBorder: AppColors.inkBorder,
    subtle: AppColors.subtle,
    disabled: AppColors.disabled,
    acid: AppColors.acid,
    onAcid: AppColors.ink,
    crown: AppColors.crown,
    successBg: AppColors.successBg,
    successFg: AppColors.successFg,
    dangerBg: AppColors.dangerBg,
    dangerFg: AppColors.dangerFg,
    infoBg: AppColors.infoBg,
    infoFg: AppColors.infoFg,
    neutralBg: AppColors.neutralBg,
    neutralFg: AppColors.neutralFg,
    warningBg: AppColors.warningBg,
    warningFg: AppColors.warningFg,
    accentBg: AppColors.accentBg,
    accentFg: AppColors.accentFg,
    destructive: AppColors.destructive,
  );

  /// Modo oscuro: los grises y estados de la app nueva (tokens.css de la
  /// referencia, 20/11/2026); el acento sigue siendo nuestro amarillo.
  /// Mismo diseño, invertido. El amarillo no cambia y siempre lleva
  /// texto oscuro encima (`onAcid`), también de noche.
  static const dark = AppPalette(
    ground: Color(0xFF121212),
    surface: Color(0xFF1E1E1E),
    surfaceStrong: Color(0xFF2A2A2A),
    line: Color(0xFF363636),
    ink: Color(0xFFFFFFFF),
    onInk: Color(0xFF0A0A0A),
    inkBorder: Color(0x40FFFFFF),
    subtle: Color(0xFF8F8F8F),
    disabled: Color(0xFF5A5A5A),
    acid: AppColors.acid,
    onAcid: Color(0xFF0A0A0A),
    crown: AppColors.crown,
    successBg: Color(0xFF173A22),
    successFg: Color(0xFF7EE09A),
    dangerBg: Color(0xFF3D1818),
    dangerFg: Color(0xFFFF9A9A),
    infoBg: Color(0xFF0C2A3D),
    infoFg: Color(0xFF7DD3FC),
    neutralBg: Color(0xFF2A2A2A),
    neutralFg: Color(0xFFD2D2D2),
    warningBg: Color(0xFF3B2C10),
    warningFg: Color(0xFFF6C66B),
    accentBg: Color(0xFF3A1342),
    accentFg: Color(0xFFF0ABFC),
    destructive: Color(0xFFE5503E),
  );

  @override
  AppPalette copyWith() => this;

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppPalette(
      ground: l(ground, other.ground),
      surface: l(surface, other.surface),
      surfaceStrong: l(surfaceStrong, other.surfaceStrong),
      line: l(line, other.line),
      ink: l(ink, other.ink),
      onInk: l(onInk, other.onInk),
      inkBorder: l(inkBorder, other.inkBorder),
      subtle: l(subtle, other.subtle),
      disabled: l(disabled, other.disabled),
      acid: l(acid, other.acid),
      onAcid: l(onAcid, other.onAcid),
      crown: l(crown, other.crown),
      successBg: l(successBg, other.successBg),
      successFg: l(successFg, other.successFg),
      dangerBg: l(dangerBg, other.dangerBg),
      dangerFg: l(dangerFg, other.dangerFg),
      infoBg: l(infoBg, other.infoBg),
      infoFg: l(infoFg, other.infoFg),
      neutralBg: l(neutralBg, other.neutralBg),
      neutralFg: l(neutralFg, other.neutralFg),
      warningBg: l(warningBg, other.warningBg),
      warningFg: l(warningFg, other.warningFg),
      accentBg: l(accentBg, other.accentBg),
      accentFg: l(accentFg, other.accentFg),
      destructive: l(destructive, other.destructive),
    );
  }
}

extension PaletaDeContexto on BuildContext {
  /// Colores del modo actual (claro u oscuro).
  AppPalette get paleta =>
      Theme.of(this).extension<AppPalette>() ?? AppPalette.light;
}
