import 'package:flutter/material.dart';

/// Tokens de color del sistema de diseño **I+**.
///
/// Regla que gobierna todo: la interfaz es blanco, negro y gris. El color solo
/// aparece donde **significa** algo — cinturones, estados y el amarillo de
/// acento. Ver la skill `diseno-i-plus`.
///
/// El código de las pantallas referencia estos tokens, nunca literales `Color`.
class AppColors {
  AppColors._();

  // ── Superficies y texto ────────────────────────────────────────────────
  /// Fondo de pantalla.
  static const Color ground = Color(0xFFFFFFFF);

  /// Fondo de tarjeta y de campos de formulario.
  static const Color surface = Color(0xFFF4F4F5);

  /// Superficie un punto más marcada (snackbars, menús, pulsado).
  static const Color surfaceStrong = Color(0xFFE9E9EC);

  /// Bordes y separadores.
  static const Color line = Color(0xFFE7E7EA);

  /// Tinta: texto principal, iconos activos y botones primarios.
  static const Color ink = Color(0xFF0A0A0A);

  /// Texto secundario y iconos inactivos.
  static const Color subtle = Color(0xFF71717A);

  /// Texto deshabilitado.
  static const Color disabled = Color(0xFFA1A1AA);

  // ── Acento ─────────────────────────────────────────────────────────────
  /// Amarillo eléctrico: día seleccionado y avisos críticos. Único color de
  /// marca; se usa con cuentagotas y siempre con texto [ink] encima.
  static const Color acid = Color(0xFFE9FF3D);

  // ── Semánticos (pastel, con su color de texto) ─────────────────────────
  static const Color successBg = Color(0xFFD1FAE5);
  static const Color successFg = Color(0xFF065F46);
  static const Color dangerBg = Color(0xFFFEE2E2);
  static const Color dangerFg = Color(0xFFB91C1C);
  static const Color infoBg = Color(0xFFE0F2FE);
  static const Color infoFg = Color(0xFF075985);
  static const Color neutralBg = Color(0xFFE4E4E7);
  static const Color neutralFg = Color(0xFF3F3F46);
  static const Color warningBg = Color(0xFFFEF3C7);
  static const Color warningFg = Color(0xFF92400E);
  static const Color accentBg = Color(0xFFFAE8FF);
  static const Color accentFg = Color(0xFFA21CAF);

  /// Rojo sólido para acciones destructivas (cancelar suscripción, borrar).
  static const Color destructive = Color(0xFFDC2626);

  // ── Cinturones ─────────────────────────────────────────────────────────
  /// Los cinturones **son el dato**, no decoración: aquí el color se queda.
  /// El blanco necesita borde para verse sobre fondo claro (ver [beltNeedsBorder]).
  ///
  /// Los cinturones mixtos de niños (`gris_blanco`, `amarillo_negro`…) no
  /// tienen entrada propia aquí: se resuelven a partir del color base
  /// (antes del `_`) más una franja del segundo color — ver [belt] y
  /// [franjaCinturon].
  static const Map<String, Color> beltColors = {
    'blanco': Color(0xFFFFFFFF),
    'azul': Color(0xFF1D8FEF),
    'morado': Color(0xFF8B2FE0),
    'marron': Color(0xFF8A4B22),
    'negro': Color(0xFF111111),
    // Niños (sistema IBJJF).
    'gris': Color(0xFF9CA3AF),
    'amarillo': Color(0xFFF5C518),
    'naranja': Color(0xFFF97316),
    'verde': Color(0xFF16A34A),
  };

  /// Borde para los cinturones demasiado claros para distinguirse del fondo.
  ///
  /// No es solo el blanco de adulto: los mixtos de niños con franja blanca
  /// (`gris_blanco`, `amarillo_blanco`, `naranja_blanco`, `verde_blanco`)
  /// perdían la franja de vista sobre fondo claro — parecían el cinturón
  /// liso, que es otro grado distinto.
  static bool beltNeedsBorder(String cinturon) =>
      cinturon == 'blanco' ||
      (esCinturonMixto(cinturon) && cinturon.split('_').contains('blanco'));

  static const Color beltBorder = Color(0xFFD4D4D8);

  /// `true` para los cinturones mixtos de niños (`<base>_<franja>`, p. ej.
  /// `gris_blanco`) — los únicos cinturones cuyo identificador lleva `_`.
  static bool esCinturonMixto(String cinturon) => cinturon.contains('_');

  static Color belt(String? cinturon) {
    if (cinturon == null) return beltColors['blanco']!;
    final base = esCinturonMixto(cinturon)
        ? cinturon.split('_').first
        : cinturon;
    return beltColors[base] ?? beltColors['blanco']!;
  }

  /// Color de la franja inferior de un cinturón mixto de niños. Solo tiene
  /// sentido cuando [esCinturonMixto] es `true`.
  static Color franjaCinturon(String cinturon) {
    final sufijo = cinturon.split('_').last;
    return beltColors[sufijo] ?? beltColors['blanco']!;
  }
}
