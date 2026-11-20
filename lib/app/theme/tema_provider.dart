import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Modo de la app que ha elegido la persona: sigue al móvil (por defecto),
/// claro u oscuro. Se guarda en el propio dispositivo.
final temaProvider = NotifierProvider<TemaNotifier, ThemeMode>(
  TemaNotifier.new,
);

class TemaNotifier extends Notifier<ThemeMode> {
  static const _clave = 'tema';

  /// Valor leído al arrancar, antes de pintar la primera pantalla, para que
  /// no parpadee en el modo equivocado. Lo rellena [cargar] desde `main`.
  static ThemeMode _inicial = ThemeMode.system;

  /// Lee el modo guardado. Si falla (almacenamiento no disponible), la app
  /// sigue al móvil: nunca debe impedir arrancar.
  static Future<void> cargar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _inicial = deTexto(prefs.getString(_clave));
    } catch (_) {
      _inicial = ThemeMode.system;
    }
  }

  static ThemeMode deTexto(String? valor) => switch (valor) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };

  @override
  ThemeMode build() => _inicial;

  Future<void> elegir(ThemeMode modo) async {
    state = modo;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_clave, modo.name);
    } catch (_) {
      // No guardarlo no es grave: el cambio ya se ve; solo se pierde al cerrar.
    }
  }
}
