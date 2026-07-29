import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'color_tokens.dart';

/// Tema de la app **I+**: claro, monocromo, con el amarillo eléctrico como
/// único acento. Ver la skill `diseno-i-plus` para las reglas completas.
///
/// Solo hay tema claro. El diseño aprobado es claro y añadir una variante
/// oscura sin pedirla duplicaría el mantenimiento de cada pantalla.
class AppTheme {
  AppTheme._();

  /// Familias tipográficas incrustadas en la app (ver `pubspec.yaml`).
  /// Nunca se cargan por red: en redes con DNS filtrado la descarga falla y
  /// el texto cae a otra fuente. Ya ocurrió en producción.
  static const String fontSans = 'InterTight';
  static const String fontMono = 'JetBrainsMono';

  /// Barra de estado oscura sobre fondo claro.
  static const SystemUiOverlayStyle overlayStyle = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
    systemNavigationBarColor: AppColors.ground,
    systemNavigationBarIconBrightness: Brightness.dark,
  );

  static ThemeData get light {
    const scheme = ColorScheme.light(
      primary: AppColors.ink,
      onPrimary: Colors.white,
      secondary: AppColors.acid,
      onSecondary: AppColors.ink,
      surface: AppColors.ground,
      onSurface: AppColors.ink,
      surfaceContainerHighest: AppColors.surface,
      error: AppColors.destructive,
      onError: Colors.white,
      outline: AppColors.line,
    );

    final text = _textTheme;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: scheme,
      fontFamily: fontSans,
      scaffoldBackgroundColor: AppColors.ground,
      canvasColor: AppColors.ground,
      dividerColor: AppColors.line,
      textTheme: text,
      splashFactory: InkSparkle.splashFactory,

      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.ground,
        foregroundColor: AppColors.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: overlayStyle,
        titleTextStyle: text.titleLarge,
      ),

      // Tarjeta: gris muy claro, esquinas de 20, sin sombra ni borde.
      cardTheme: CardThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),

      // Barra inferior: activo en negro, inactivo en gris.
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.ground,
        surfaceTintColor: Colors.transparent,
        indicatorColor: Colors.transparent,
        elevation: 0,
        height: 68,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 22,
            color: states.contains(WidgetState.selected)
                ? AppColors.ink
                : AppColors.disabled,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontFamily: fontSans,
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: states.contains(WidgetState.selected)
                ? AppColors.ink
                : AppColors.disabled,
          ),
        ),
      ),

      // Campos: relleno gris, sin borde, esquinas de 14.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        border: _inputBorder(AppColors.line),
        enabledBorder: _inputBorder(AppColors.line),
        focusedBorder: _inputBorder(AppColors.ink, width: 1.5),
        errorBorder: _inputBorder(AppColors.destructive),
        focusedErrorBorder: _inputBorder(AppColors.destructive, width: 1.5),
        hintStyle: const TextStyle(color: AppColors.disabled),
        labelStyle: const TextStyle(color: AppColors.subtle),
      ),

      // Botón principal: negro, texto blanco, ancho completo.
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.ink,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.surfaceStrong,
          disabledForegroundColor: AppColors.disabled,
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
          foregroundColor: AppColors.ink,
          minimumSize: const Size.fromHeight(52),
          side: const BorderSide(color: Color(0x400A0A0A)),
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
          foregroundColor: AppColors.ink,
          textStyle: const TextStyle(
            fontFamily: fontSans,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.ink,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),

      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.ink,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(18)),
        ),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surface,
        side: BorderSide.none,
        labelStyle: const TextStyle(
          fontFamily: fontMono,
          fontSize: 11,
          letterSpacing: 0.8,
          color: AppColors.neutralFg,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.ground,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titleTextStyle: _textTheme.titleLarge,
      ),

      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.ground,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.ink,
        contentTextStyle: const TextStyle(
          fontFamily: fontSans,
          fontSize: 14,
          color: Colors.white,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),

      dividerTheme: const DividerThemeData(
        color: AppColors.line,
        thickness: 1,
        space: 1,
      ),

      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.ink,
        textColor: AppColors.ink,
      ),

      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.ink,
        linearTrackColor: AppColors.line,
        circularTrackColor: AppColors.line,
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Colors.white : Colors.white,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AppColors.ink
              : AppColors.surfaceStrong,
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
  static const TextTheme _textTheme = TextTheme(
    displayLarge: TextStyle(
      fontSize: 34,
      fontWeight: FontWeight.w800,
      letterSpacing: -1,
      height: 1.05,
      color: AppColors.ink,
    ),
    headlineMedium: TextStyle(
      fontSize: 26,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.6,
      height: 1.1,
      color: AppColors.ink,
    ),
    titleLarge: TextStyle(
      fontSize: 19,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.4,
      color: AppColors.ink,
    ),
    titleMedium: TextStyle(
      fontSize: 17,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.2,
      color: AppColors.ink,
    ),
    titleSmall: TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w600,
      color: AppColors.ink,
    ),
    bodyLarge: TextStyle(fontSize: 16, height: 1.45, color: AppColors.ink),
    bodyMedium: TextStyle(fontSize: 15, height: 1.45, color: AppColors.ink),
    bodySmall: TextStyle(fontSize: 13, height: 1.4, color: AppColors.subtle),
    labelLarge: TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w600,
      color: AppColors.ink,
    ),
    // Etiqueta monoespaciada en mayúsculas: fechas, estados, identificadores.
    labelSmall: TextStyle(
      fontFamily: fontMono,
      fontSize: 11,
      fontWeight: FontWeight.w500,
      letterSpacing: 1.1,
      color: AppColors.subtle,
    ),
  );
}
