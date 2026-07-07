import 'package:flutter/material.dart';

import 'color_tokens.dart';

/// App themes. A shared [_build] keeps the dark and light variants in sync so
/// component styling (cards, inputs, buttons…) never drifts between them.
class AppTheme {
  AppTheme._();

  static ThemeData get dark => _build(
        brightness: Brightness.dark,
        surfaceBase: AppColors.surfaceBase,
        surfaceElevated: AppColors.surfaceElevated,
        surfaceElevatedHigh: AppColors.surfaceElevatedHigh,
        textPrimary: AppColors.textPrimary,
        divider: AppColors.divider,
      );

  static ThemeData get light => _build(
        brightness: Brightness.light,
        surfaceBase: AppColors.lightSurfaceBase,
        surfaceElevated: AppColors.lightSurfaceElevated,
        surfaceElevatedHigh: AppColors.lightSurfaceElevatedHigh,
        textPrimary: AppColors.lightTextPrimary,
        divider: AppColors.lightDivider,
      );

  static ThemeData _build({
    required Brightness brightness,
    required Color surfaceBase,
    required Color surfaceElevated,
    required Color surfaceElevatedHigh,
    required Color textPrimary,
    required Color divider,
  }) {
    final base = ColorScheme.fromSeed(
      brightness: brightness,
      seedColor: AppColors.seed,
      surface: surfaceBase,
      primary: AppColors.accentPrimary,
      secondary: AppColors.accentSecondary,
      error: AppColors.danger,
    );

    // Uses the platform's default font (no network dependency — google_fonts'
    // runtime font fetching failed on some networks, e.g. DNS-filtered Wi-Fi).
    final textTheme = ThemeData(brightness: brightness).textTheme.apply(
          bodyColor: textPrimary,
          displayColor: textPrimary,
        );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: base,
      scaffoldBackgroundColor: surfaceBase,
      textTheme: textTheme,
      dividerColor: divider,
      appBarTheme: AppBarTheme(
        backgroundColor: surfaceBase,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: surfaceElevated,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: EdgeInsets.zero,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surfaceElevated,
        indicatorColor: AppColors.accentPrimary.withValues(alpha: 0.25),
        surfaceTintColor: Colors.transparent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceElevated,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accentPrimary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surfaceElevatedHigh,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
