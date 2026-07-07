import 'package:flutter/material.dart';

/// Semantic color tokens for the dark-mode-first design system.
/// Feature code should reference these, not raw [Color] literals.
class AppColors {
  AppColors._();

  static const Color seed = Color(0xFF6C5CE7);

  static const Color surfaceBase = Color(0xFF121214);
  static const Color surfaceElevated = Color(0xFF1C1C1F);
  static const Color surfaceElevatedHigh = Color(0xFF262629);

  static const Color accentPrimary = Color(0xFF6C5CE7);
  static const Color accentSecondary = Color(0xFF00D9C0);

  static const Color success = Color(0xFF33D17A);
  static const Color warning = Color(0xFFFFB020);
  static const Color danger = Color(0xFFFF5A5F);

  static const Color textPrimary = Color(0xFFF2F2F5);
  static const Color textSecondary = Color(0xFFA0A0AA);
  static const Color textDisabled = Color(0xFF5C5C66);

  static const Color divider = Color(0xFF2A2A2E);

  /// Belt colors reused in ranking badges and the technique tree (module 4).
  static const Map<String, Color> beltColors = {
    'blanco': Color(0xFFF2F2F5),
    'azul': Color(0xFF2E6BFF),
    'morado': Color(0xFF8E44E0),
    'marron': Color(0xFF8B5E3C),
    'negro': Color(0xFF121214),
  };

  /// Progress-state colors for module 4 (árbol de progreso).
  static const Color tecnicaBloqueada = Color(0xFF5C5C66);
  static const Color tecnicaEnProceso = Color(0xFFFFB020);
  static const Color tecnicaConseguida = Color(0xFF33D17A);
}
