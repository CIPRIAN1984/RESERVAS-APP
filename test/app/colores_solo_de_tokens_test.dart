import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Skill `diseno-i-plus` §8: «Nunca escribas un color a mano. Todo sale de
/// los tokens». En la auditoría del 27/09/2026 había 19 colores escritos a
/// mano fuera de `color_tokens.dart`. Esta prueba falla si vuelve a colarse
/// uno, y dice en qué fichero y línea.
void main() {
  test('ningún color escrito a mano fuera de color_tokens.dart', () {
    final colorSuelto = RegExp(
      r'Colors\.(white|black|red|green|blue|grey|orange|amber|yellow)\b|'
      r'Color\(0x',
    );
    final encontrados = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      if (f.path.endsWith('color_tokens.dart') ||
          f.path.endsWith('app_palette.dart')) {
        continue;
      }
      final lineas = f.readAsLinesSync();
      for (var i = 0; i < lineas.length; i++) {
        final linea = lineas[i].trimLeft();
        if (linea.startsWith('//')) continue;
        if (colorSuelto.hasMatch(linea)) {
          encontrados.add('${f.path}:${i + 1}: $linea');
        }
      }
    }
    expect(encontrados, isEmpty, reason: encontrados.join('\n'));
  });

  /// Dos modos (20/11/2026): los colores que cambian con el modo se leen de
  /// `context.paleta`. Un `AppColors.ink` suelto en una pantalla se quedaría
  /// negro sobre fondo negro en modo oscuro. Solo los cinturones (`belt…`,
  /// `esCinturonMixto`, `franjaCinturon`) son fijos.
  test('las pantallas leen los colores del tema, no AppColors fijos', () {
    final fijo = RegExp(r'AppColors\.(?!belt|esCinturonMixto|franjaCinturon)');
    final encontrados = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      if (f.path.contains('/app/theme/')) continue;
      final lineas = f.readAsLinesSync();
      for (var i = 0; i < lineas.length; i++) {
        if (lineas[i].trimLeft().startsWith('//')) continue;
        if (fijo.hasMatch(lineas[i])) {
          encontrados.add('${f.path}:${i + 1}: ${lineas[i].trim()}');
        }
      }
    }
    expect(encontrados, isEmpty, reason: encontrados.join('\n'));
  });
}
