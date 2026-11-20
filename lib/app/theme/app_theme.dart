import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_palette.dart';

/// Tema de la app **I+**: claro, monocromo, con el amarillo eléctrico como
/// único acento. Ver la skill `diseno-i-plus` para las reglas completas.
///
/// Dos modos: claro (el de siempre) y oscuro (el de la app nueva, pedido por
/// Cipri el 20/11/2026). Los colores salen de [AppPalette].
class AppTheme {
  AppTheme._();

  /// Familias tipográficas incrustadas en la app (ver `pubspec.yaml`).
  /// Nunca se cargan por red: en redes con DNS filtrado la descarga falla y
  /// el texto cae a otra fuente. Ya ocurrió en producción.
  static const String fontSans = 'InterTight';
  static const String fontMono = 'JetBrainsMono';

  /// Barra de estado: iconos oscuros sobre fondo claro y claros sobre oscuro.
  static SystemUiOverlayStyle overlayFor(AppPalette p, Brightness b) =>
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: b == Brightness.light
            ? Brightness.dark
            : Brightness.light,
        statusBarBrightness: b,
        systemNavigationBarColor: p.ground,
        systemNavigationBarIconBrightness: b == Brightness.light
            ? Brightness.dark
            : Brightness.light,
      );

  static final ThemeData light = _build(AppPalette.light, Brightness.light);
  static final ThemeData dark = _build(AppPalette.dark, Brightness.dark);

  static ThemeData _build(AppPalette p, Brightness brightness) {
    final scheme = ColorScheme(
      brightness: brightness,
      primary: p.ink,
      onPrimary: p.onInk,
      secondary: p.acid,
      onSecondary: p.ink,
      surface: p.ground,
      onSurface: p.ink,
      surfaceContainerHighest: p.surface,
      error: p.destructive,
      onError: p.onInk,
      outline: p.line,
    );

    final text = _textTheme(p);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      extensions: [p],
      colorScheme: scheme,
      fontFamily: fontSans,
      scaffoldBackgroundColor: p.ground,
      canvasColor: p.ground,
      dividerColor: p.line,
      textTheme: text,
      splashFactory: InkSparkle.splashFactory,

      appBarTheme: AppBarTheme(
        backgroundColor: p.ground,
        foregroundColor: p.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: overlayFor(p, brightness),
        // `copyWith(fontFamily:)` y no `text.titleLarge` a secas: el
        // `fontFamily` de arriba solo lo aplica Flutter al `textTheme`, no a
        // los estilos que se pasan sueltos a un tema de componente. Sin esto
        // el título sale con la letra del sistema. Y no vale
        // `_textTheme.apply(fontFamily:)`, que pisaría la mono de las
        // etiquetas pequeñas.
        titleTextStyle: text.titleLarge?.copyWith(fontFamily: fontSans),
      ),

      // Tarjeta: gris muy claro, esquinas de 20, sin sombra ni borde.
      cardTheme: CardThemeData(
        color: p.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),

      // Barra inferior: activo en negro, inactivo en gris.
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: p.ground,
        surfaceTintColor: Colors.transparent,
        indicatorColor: Colors.transparent,
        elevation: 0,
        height: 68,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 22,
            color: states.contains(WidgetState.selected) ? p.ink : p.disabled,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontFamily: fontSans,
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: states.contains(WidgetState.selected) ? p.ink : p.disabled,
          ),
        ),
      ),

      // Campos: relleno gris, sin borde, esquinas de 14.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        border: _inputBorder(p.line),
        enabledBorder: _inputBorder(p.line),
        focusedBorder: _inputBorder(p.ink, width: 1.5),
        errorBorder: _inputBorder(p.destructive),
        focusedErrorBorder: _inputBorder(p.destructive, width: 1.5),
        hintStyle: TextStyle(color: p.disabled),
        labelStyle: TextStyle(color: p.subtle),
      ),

      // Botón principal: negro, texto blanco, ancho completo.
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: p.ink,
          foregroundColor: p.onInk,
          disabledBackgroundColor: p.surfaceStrong,
          disabledForegroundColor: p.disabled,
          elevation: 0,
          minimumSize: const Size.fromHeight(52),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          textStyle: const TextStyle(
            fontFamily: fontSans,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),

      // Botón secundario: borde fino, fondo transparente.
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.ink,
          minimumSize: const Size.fromHeight(52),
          side: BorderSide(color: p.inkBorder),
          textStyle: const TextStyle(
            fontFamily: fontSans,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.ink,
          textStyle: const TextStyle(
            fontFamily: fontSans,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: p.ink,
          foregroundColor: p.onInk,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: p.ink,
        foregroundColor: p.onInk,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(18)),
        ),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: p.surface,
        side: BorderSide.none,
        labelStyle: TextStyle(
          fontFamily: fontMono,
          fontSize: 11,
          letterSpacing: 0.8,
          color: p.neutralFg,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: p.ground,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        // Mismo caso que en la barra superior: sin el `fontFamily` explícito,
        // el título de TODOS los diálogos de la app sale con la letra del
        // sistema en vez de con Inter Tight.
        titleTextStyle: text.titleLarge?.copyWith(fontFamily: fontSans),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.ground,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: p.ink,
        contentTextStyle: TextStyle(
          fontFamily: fontSans,
          fontSize: 14,
          color: p.onInk,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),

      dividerTheme: DividerThemeData(color: p.line, thickness: 1, space: 1),

      listTileTheme: ListTileThemeData(iconColor: p.ink, textColor: p.ink),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: p.ink,
        linearTrackColor: p.line,
        circularTrackColor: p.line,
      ),

      switchTheme: SwitchThemeData(
        // Blanco en los dos estados: lo que cambia es la pista.
        thumbColor: WidgetStatePropertyAll(p.onInk),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? p.ink : p.surfaceStrong,
        ),
      ),
    );
  }

  static OutlineInputBorder _inputBorder(Color color, {double width = 1}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: color, width: width),
      );

  /// Escala tipográfica. Los títulos van muy marcados y con el interletrado
  /// apretado; el cuerpo, en peso normal y cómodo de leer.
  static TextTheme _textTheme(AppPalette p) => TextTheme(
    displayLarge: TextStyle(
      fontSize: 34,
      fontWeight: FontWeight.w800,
      letterSpacing: -1,
      height: 1.05,
      color: p.ink,
    ),
    headlineMedium: TextStyle(
      fontSize: 26,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.6,
      height: 1.1,
      color: p.ink,
    ),
    titleLarge: TextStyle(
      fontSize: 19,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.4,
      color: p.ink,
    ),
    titleMedium: TextStyle(
      fontSize: 17,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.2,
      color: p.ink,
    ),
    titleSmall: TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w600,
      color: p.ink,
    ),
    bodyLarge: TextStyle(fontSize: 16, height: 1.45, color: p.ink),
    bodyMedium: TextStyle(fontSize: 15, height: 1.45, color: p.ink),
    bodySmall: TextStyle(fontSize: 13, height: 1.4, color: p.subtle),
    labelLarge: TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w600,
      color: p.ink,
    ),
    // Etiqueta monoespaciada en mayúsculas: fechas, estados, identificadores.
    labelSmall: TextStyle(
      fontFamily: fontMono,
      fontSize: 11,
      fontWeight: FontWeight.w500,
      letterSpacing: 1.1,
      color: p.subtle,
    ),
  );
}
