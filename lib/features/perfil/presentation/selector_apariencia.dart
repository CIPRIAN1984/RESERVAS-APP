import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/tema_provider.dart';
import '../../../shared/widgets/pantalla.dart';

/// Elegir cómo se ve la app: como el móvil, siempre claro o siempre oscuro.
/// Vive en Perfil, la única pantalla que tienen todos los roles.
class SelectorApariencia extends ConsumerWidget {
  const SelectorApariencia({super.key});

  static const _modos = [ThemeMode.system, ThemeMode.light, ThemeMode.dark];
  static const _etiquetas = ['Como el móvil', 'Claro', 'Oscuro'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actual = ref.watch(temaProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Apariencia', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          'Se guarda en este dispositivo.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        PestanasPildora(
          valor: _modos.indexOf(actual),
          etiquetas: _etiquetas,
          onCambio: (i) => ref.read(temaProvider.notifier).elegir(_modos[i]),
        ),
      ],
    );
  }
}
