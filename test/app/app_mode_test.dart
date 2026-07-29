import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:itaca/app/app_mode.dart';

void main() {
  group('AppMode', () {
    test('cada modo lleva al contrario', () {
      expect(AppMode.entrenamiento.contrario, AppMode.gestor);
      expect(AppMode.gestor.contrario, AppMode.entrenamiento);
    });

    test('el botón anuncia el modo al que va, no en el que estás', () {
      expect(AppMode.entrenamiento.etiquetaCambio, 'Cambiar a Gestor');
      expect(AppMode.gestor.etiquetaCambio, 'Cambiar a Entrenamiento');
    });

    test('se arranca siempre en Entrenamiento', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(appModeProvider), AppMode.entrenamiento);
    });

    test('alternar cambia el estado y devuelve el modo nuevo', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final nuevo = container.read(appModeProvider.notifier).alternar();
      expect(nuevo, AppMode.gestor);
      expect(container.read(appModeProvider), AppMode.gestor);

      container.read(appModeProvider.notifier).alternar();
      expect(container.read(appModeProvider), AppMode.entrenamiento);
    });
  });
}
