import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:itaca/app/theme/app_theme.dart';

/// Carga las tipografías reales en el entorno de pruebas.
///
/// Es obligatorio para cualquier prueba visual: el motor de pruebas no lee
/// `pubspec.yaml`, así que sin esto el texto se dibujaría como cajas negras
/// y los iconos como cuadros vacíos.
Future<void> cargarTipografias() async {
  Future<void> cargar(String familia, List<String> rutas) async {
    final loader = FontLoader(familia);
    for (final ruta in rutas) {
      if (!File(ruta).existsSync()) continue;
      loader.addFont(
        File(ruta).readAsBytes().then((b) => ByteData.view(b.buffer)),
      );
    }
    await loader.load();
  }

  await cargar(AppTheme.fontSans, const [
    'assets/fonts/InterTight-Regular.ttf',
    'assets/fonts/InterTight-Medium.ttf',
    'assets/fonts/InterTight-SemiBold.ttf',
    'assets/fonts/InterTight-Bold.ttf',
    'assets/fonts/InterTight-ExtraBold.ttf',
  ]);
  await cargar(AppTheme.fontMono, const [
    'assets/fonts/JetBrainsMono-Regular.ttf',
    'assets/fonts/JetBrainsMono-Medium.ttf',
  ]);

  // Los iconos vienen del SDK de Flutter, no del proyecto.
  await cargar('MaterialIcons', const [
    '/opt/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  ]);
}
