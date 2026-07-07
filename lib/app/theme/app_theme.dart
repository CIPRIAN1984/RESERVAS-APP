import 'package:flutter/material.dart';

import 'color_tokens.dart';

/// Single static dark theme for the MVP. Kept additive so a light variant
/// can be introduced later without restructuring feature code.
class AppTheme {
  AppTheme._();

  static ThemeData get dark {
    final base = ColorScheme.fromSeed(
      brightness: Brightness.dark,
      seedColor: AppColors.seed,
      surface: AppColors.surfaceBase,
      primary: AppColors.accentPrimary,
      secondary: AppColors.accentSecondary,
      error: AppColors.danger,
    );

    // Uses the platform's default font (no network dependency — google_fonts'
    // runtime font fetching failed on some networks, e.g. DNS-filtered Wi-Fi).
    final textTheme = ThemeData(brightness: Brightness.dark).textTheme.apply(
          bodyColor: AppColors.textPrimary,
          displayColor: AppColors.textPrimary,
        );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: base,
      scaffoldBackgroundColor: AppColors.surfaceBase,
      textTheme: textTheme,
      dividerColor: AppColors.divider,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surfaceBase,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surfaceElevated,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: EdgeInsets.zero,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surfaceElevated,
        indicatorColor: AppColors.accentPrimary.withValues(alpha: 0.25),
        surfaceTintColor: Colors.transparent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceElevated,
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
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: AppColors.surfaceElevatedHigh,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
