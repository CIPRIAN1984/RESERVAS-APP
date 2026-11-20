import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:itaca/app/theme/modo_tema.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('por defecto sigue al sistema', () {
    SharedPreferences.setMockInitialValues({});
    final c = ProviderContainer();
    addTearDown(c.dispose);
    expect(c.read(modoTemaProvider), ThemeMode.system);
  });

  test('recuerda el modo elegido', () async {
    SharedPreferences.setMockInitialValues({});
    final c = ProviderContainer();
    addTearDown(c.dispose);
    await c.read(modoTemaProvider.notifier).elegir(ThemeMode.dark);
    expect(c.read(modoTemaProvider), ThemeMode.dark);

    final otra = ProviderContainer();
    addTearDown(otra.dispose);
    otra.read(modoTemaProvider);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(otra.read(modoTemaProvider), ThemeMode.dark);
  });

  test('un valor desconocido guardado vuelve al sistema', () {
    expect(modoDesdeTexto('raro'), ThemeMode.system);
    expect(modoDesdeTexto(null), ThemeMode.system);
  });
}
