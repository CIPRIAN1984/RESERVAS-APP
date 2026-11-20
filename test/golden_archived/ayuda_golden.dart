import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:itaca/app/theme/app_theme.dart';
import 'package:itaca/app/theme/color_tokens.dart';

/// Carga las tipografías reales en el entorno de pruebas.
///
/// Es obligatorio para cualquier prueba visual: el motor de pruebas no lee
/// `pubspec.yaml`, así que sin esto el texto se dibujaría como cajas negras
/// y los iconos como cuadros vacíos.
Future<void> cargarTipografias() async {
  // Las fechas en castellano las inicializa main.dart; en pruebas hay que
  // hacerlo a mano o cualquier pantalla con fechas revienta.
  await initializeDateFormatting('es_ES');
  Intl.defaultLocale = 'es_ES';

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

  // Los iconos vienen del SDK de Flutter, no del proyecto, y el SDK no está
  // en el mismo sitio en cada máquina.
  final sdk = File(Platform.resolvedExecutable).parent.parent.parent.path;
  await cargar('MaterialIcons', [
    '/opt/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    '$sdk/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  ]);
}

/// Las imágenes solo se comparan cuando se revisan en local.
///
/// El dibujado de tipografías varía entre máquinas, así que comparar píxeles
/// en el control automático daría falsos fallos constantes. Las
/// comprobaciones de comportamiento (que el texto y los botones estén donde
/// deben) sí se ejecutan en todas partes.
bool get comparaImagenes => Platform.environment['CI'] != 'true';

/// `OSCURO=1 flutter test --tags=golden` dibuja las mismas pantallas en modo
/// oscuro y guarda las imágenes con el sufijo `_oscuro`. Sin la variable,
/// todo sigue exactamente igual que antes (modo claro).
bool get modoOscuro => Platform.environment['OSCURO'] == '1';

/// Tema para las pruebas visuales, en el modo que toque. También activa la
/// paleta de `AppColors`, que en la app real fija `app.dart`.
ThemeData temaDePrueba() {
  AppColors.usar(modoOscuro ? AppPalette.dark : AppPalette.light);
  return modoOscuro ? AppTheme.dark : AppTheme.light;
}

/// Compara con la imagen guardada solo si procede.
Future<void> comparaCon(Finder finder, String ruta) async {
  if (!comparaImagenes) return;
  final destino = modoOscuro ? ruta.replaceFirst('.png', '_oscuro.png') : ruta;
  await expectLater(finder, matchesGoldenFile(destino));
}
