import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:itaca/app/theme/app_palette.dart';

import '../../../core/web/instalacion.dart';

/// «Instala la app»: tenerla en la pantalla de inicio sin pasar por las
/// tiendas. Solo sale en la web y solo cuando se puede instalar; en cualquier
/// otro caso no ocupa sitio.
class TarjetaInstalarApp extends ConsumerStatefulWidget {
  const TarjetaInstalarApp({super.key});

  @override
  ConsumerState<TarjetaInstalarApp> createState() => _TarjetaInstalarAppState();
}

class _TarjetaInstalarAppState extends ConsumerState<TarjetaInstalarApp> {
  bool _instalando = false;

  Future<void> _instalar() async {
    setState(() => _instalando = true);
    await ref.read(instalacionProvider).instalar();
    if (mounted) setState(() => _instalando = false);
  }

  @override
  Widget build(BuildContext context) {
    final estado = ref.watch(instalacionProvider).estado();
    if (estado == EstadoInstalacion.noDisponible ||
        estado == EstadoInstalacion.yaInstalada) {
      return const SizedBox.shrink();
    }
    final texto = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.install_mobile, color: context.paleta.ink),
                  const SizedBox(width: 10),
                  Text('Instala la app', style: texto.titleMedium),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                estado == EstadoInstalacion.conBoton
                    ? 'Ábrela desde la pantalla de inicio de tu móvil, sin '
                          'tiendas y a pantalla completa.'
                    : 'En Safari pulsa Compartir y luego «Añadir a pantalla '
                          'de inicio». Se abrirá como una app, sin pasar por '
                          'la tienda.',
                style: texto.bodyMedium,
              ),
              if (estado == EstadoInstalacion.conBoton) ...[
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _instalando ? null : _instalar,
                  child: const Text('Instalar'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
