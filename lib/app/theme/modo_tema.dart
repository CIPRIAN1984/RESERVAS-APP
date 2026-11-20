import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Modo de color elegido por la persona: el del sistema, claro u oscuro.
/// Se guarda en el dispositivo; si no se puede leer o escribir, la app sigue
/// funcionando con el del sistema.
const _clave = 'modo_tema';

ThemeMode modoDesdeTexto(String? texto) => switch (texto) {
  'claro' => ThemeMode.light,
  'oscuro' => ThemeMode.dark,
  _ => ThemeMode.system,
};

String modoATexto(ThemeMode modo) => switch (modo) {
  ThemeMode.light => 'claro',
  ThemeMode.dark => 'oscuro',
  ThemeMode.system => 'sistema',
};

class ModoTemaNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    _cargar();
    return ThemeMode.system;
  }

  Future<void> _cargar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final guardado = modoDesdeTexto(prefs.getString(_clave));
      if (guardado != state) state = guardado;
    } catch (_) {
      // Sin almacenamiento: nos quedamos con el modo del sistema.
    }
  }

  Future<void> elegir(ThemeMode modo) async {
    state = modo;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_clave, modoATexto(modo));
    } catch (_) {
      // No se pudo guardar: el cambio vale para esta sesión.
    }
  }
}

final modoTemaProvider = NotifierProvider<ModoTemaNotifier, ThemeMode>(
  ModoTemaNotifier.new,
);
