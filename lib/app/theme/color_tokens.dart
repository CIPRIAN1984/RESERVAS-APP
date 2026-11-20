import 'package:flutter/material.dart';

/// Paleta de un modo (claro u oscuro) del sistema de diseño **I+**.
///
/// Regla que gobierna todo: la interfaz es blanco, negro y gris (o su
/// inversa en oscuro). El color solo aparece donde **significa** algo —
/// cinturones, estados y el amarillo de acento. Ver la skill `diseno-i-plus`.
///
/// Las pantallas no usan esta clase directamente: leen [AppColors], que
/// apunta a la paleta del modo activo.
@immutable
class AppPalette {
  const AppPalette({
    required this.brightness,
    required this.ground,
    required this.surface,
    required this.surfaceStrong,
    required this.line,
    required this.ink,
    required this.onInk,
    required this.inkBorder,
    required this.subtle,
    required this.disabled,
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
    required this.beltBorder,
  });

  final Brightness brightness;

  /// Fondo de pantalla.
  final Color ground;

  /// Fondo de tarjeta y de campos de formulario.
  final Color surface;

  /// Superficie un punto más marcada (snackbars, menús, pulsado).
  final Color surfaceStrong;

  /// Bordes y separadores.
  final Color line;

  /// Tinta: texto principal, iconos activos y botones primarios.
  final Color ink;

  /// Texto e iconos sobre tinta: botones primarios, pestaña activa,
  /// indicadores de carga dentro de un botón de tinta.
  final Color onInk;

  /// Borde del botón secundario: la tinta al 25 %.
  final Color inkBorder;

  /// Texto secundario y iconos inactivos.
  final Color subtle;

  /// Texto deshabilitado.
  final Color disabled;

  final Color successBg;
  final Color successFg;
  final Color dangerBg;
  final Color dangerFg;
  final Color infoBg;
  final Color infoFg;
  final Color neutralBg;
  final Color neutralFg;
  final Color warningBg;
  final Color warningFg;
  final Color accentBg;
  final Color accentFg;

  /// Rojo sólido para acciones destructivas (cancelar suscripción, borrar).
  final Color destructive;

  /// Borde de los cinturones que se perderían contra el fondo.
  final Color beltBorder;

  bool get esOscuro => brightness == Brightness.dark;

  /// Modo claro: el diseño aprobado en julio de 2026. No cambia.
  static const AppPalette light = AppPalette(
    brightness: Brightness.light,
    ground: Color(0xFFFFFFFF),
    surface: Color(0xFFF4F4F5),
    surfaceStrong: Color(0xFFE9E9EC),
    line: Color(0xFFE7E7EA),
    ink: Color(0xFF0A0A0A),
    onInk: Color(0xFFFFFFFF),
    inkBorder: Color(0x400A0A0A),
    subtle: Color(0xFF71717A),
    disabled: Color(0xFFA1A1AA),
    successBg: Color(0xFFD1FAE5),
    successFg: Color(0xFF065F46),
    dangerBg: Color(0xFFFEE2E2),
    dangerFg: Color(0xFFB91C1C),
    infoBg: Color(0xFFE0F2FE),
    infoFg: Color(0xFF075985),
    neutralBg: Color(0xFFE4E4E7),
    neutralFg: Color(0xFF3F3F46),
    warningBg: Color(0xFFFEF3C7),
    warningFg: Color(0xFF92400E),
    accentBg: Color(0xFFFAE8FF),
    accentFg: Color(0xFFA21CAF),
    destructive: Color(0xFFDC2626),
    beltBorder: Color(0xFFD4D4D8),
  );

  /// Modo oscuro: casi negro con tarjetas gris oscuro, tinta blanca y los
  /// estados como fondo oscuro teñido con texto claro. Misma regla de color:
  /// solo cinturones, estados y el amarillo de acento.
  static const AppPalette dark = AppPalette(
    brightness: Brightness.dark,
    ground: Color(0xFF121212),
    surface: Color(0xFF1E1E1E),
    surfaceStrong: Color(0xFF2A2A2A),
    line: Color(0xFF2C2C2C),
    ink: Color(0xFFFFFFFF),
    onInk: Color(0xFF0A0A0A),
    inkBorder: Color(0x40FFFFFF),
    subtle: Color(0xFF9A9AA3),
    disabled: Color(0xFF5C5C63),
    successBg: Color(0xFF173A22),
    successFg: Color(0xFF7EE09A),
    dangerBg: Color(0xFF3D1818),
    dangerFg: Color(0xFFFF9A9A),
    infoBg: Color(0xFF10304A),
    infoFg: Color(0xFF8CCBFF),
    neutralBg: Color(0xFF2A2A2A),
    neutralFg: Color(0xFFD2D2D6),
    warningBg: Color(0xFF3B2C10),
    warningFg: Color(0xFFF6C66B),
    accentBg: Color(0xFF3A1A44),
    accentFg: Color(0xFFE7A6F5),
    destructive: Color(0xFFEF4444),
    beltBorder: Color(0xFF55555C),
  );
}

/// Tokens de color del sistema de diseño **I+**.
///
/// El código de las pantallas referencia estos tokens, nunca literales
/// `Color`. Los valores que dependen del modo leen la paleta activa
/// ([usar]); la fija la app en un único sitio (`app.dart`) y hace que toda
/// la interfaz se vuelva a dibujar al cambiar de modo.
class AppColors {
  AppColors._();

  static AppPalette _paleta = AppPalette.light;

  /// Paleta del modo activo.
  static AppPalette get paleta => _paleta;

  /// Cambia el modo activo. Solo lo llama la app al elegir el tema.
  static void usar(AppPalette p) => _paleta = p;

  // ── Superficies y texto ────────────────────────────────────────────────
  /// Fondo de pantalla.
  static Color get ground => _paleta.ground;

  /// Fondo de tarjeta y de campos de formulario.
  static Color get surface => _paleta.surface;

  /// Superficie un punto más marcada (snackbars, menús, pulsado).
  static Color get surfaceStrong => _paleta.surfaceStrong;

  /// Bordes y separadores.
  static Color get line => _paleta.line;

  /// Tinta: texto principal, iconos activos y botones primarios.
  static Color get ink => _paleta.ink;

  /// Texto e iconos sobre tinta: botones primarios, pestaña activa,
  /// indicadores de carga dentro de un botón negro.
  static Color get onInk => _paleta.onInk;

  /// Borde del botón secundario: la tinta al 25 %.
  static Color get inkBorder => _paleta.inkBorder;

  /// Texto secundario y iconos inactivos.
  static Color get subtle => _paleta.subtle;

  /// Texto deshabilitado.
  static Color get disabled => _paleta.disabled;

  // ── Acento ─────────────────────────────────────────────────────────────
  /// Amarillo eléctrico: día seleccionado y avisos críticos. Único color de
  /// marca; se usa con cuentagotas y siempre con texto [ink] encima.
  static const Color acid = Color(0xFFE9FF3D);

  /// Texto e iconos sobre el amarillo [acid]: siempre oscuros, también en el
  /// modo oscuro (donde [ink] es blanco y no se leería sobre el amarillo).
  static const Color onAcid = Color(0xFF0A0A0A);

  /// Corona ámbar del primero del podio del ranking.
  static const Color crown = Color(0xFFE9A800);

  // ── Semánticos (pastel, con su color de texto) ─────────────────────────
  static Color get successBg => _paleta.successBg;
  static Color get successFg => _paleta.successFg;
  static Color get dangerBg => _paleta.dangerBg;
  static Color get dangerFg => _paleta.dangerFg;
  static Color get infoBg => _paleta.infoBg;
  static Color get infoFg => _paleta.infoFg;
  static Color get neutralBg => _paleta.neutralBg;
  static Color get neutralFg => _paleta.neutralFg;
  static Color get warningBg => _paleta.warningBg;
  static Color get warningFg => _paleta.warningFg;
  static Color get accentBg => _paleta.accentBg;
  static Color get accentFg => _paleta.accentFg;

  /// Rojo sólido para acciones destructivas (cancelar suscripción, borrar).
  static Color get destructive => _paleta.destructive;

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

  /// Borde para los cinturones que se perderían contra el fondo.
  ///
  /// En claro, los de color blanco: no solo el blanco de adulto, también los
  /// mixtos de niños con franja blanca (`gris_blanco`, `amarillo_blanco`…),
  /// que perdían la franja de vista y parecían el cinturón liso, que es otro
  /// grado distinto. En oscuro pasa lo mismo con el negro (`negro`,
  /// `amarillo_negro`…) y el blanco, en cambio, ya se ve solo.
  static bool beltNeedsBorder(String cinturon) {
    final perdido = _paleta.esOscuro ? 'negro' : 'blanco';
    return cinturon == perdido ||
        (esCinturonMixto(cinturon) && cinturon.split('_').contains(perdido));
  }

  static Color get beltBorder => _paleta.beltBorder;

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
