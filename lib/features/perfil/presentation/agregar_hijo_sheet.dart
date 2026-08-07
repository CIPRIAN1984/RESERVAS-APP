import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/profile_providers.dart';

Future<void> mostrarAgregarHijoSheet(BuildContext context, WidgetRef ref) async {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _AgregarHijoSheet(),
  );
}

class _AgregarHijoSheet extends ConsumerStatefulWidget {
  const _AgregarHijoSheet();

  @override
  ConsumerState<_AgregarHijoSheet> createState() => _AgregarHijoSheetState();
}

class _AgregarHijoSheetState extends ConsumerState<_AgregarHijoSheet> {
  final _nombre = TextEditingController();
  final _apellidos = TextEditingController();
  String? _cinturon;
  bool _guardando = false;

  @override
  void dispose() {
    _nombre.dispose();
    _apellidos.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final nombre = _nombre.text.trim();
    if (nombre.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El nombre es obligatorio.')),
      );
      return;
    }

    setState(() => _guardando = true);
    try {
      await ref.read(familiaRepositoryProvider).crearHijo(
        nombre: nombre,
        apellidos: _apellidos.text.trim().isEmpty ? null : _apellidos.text.trim(),
        cinturon: _cinturon,
      );

      // Invalidar la lista para recargar
      ref.invalidate(hijosProvider);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$nombre agregado.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.of(context).viewInsets.bottom;

    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Agregar hijo',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nombre,
              enabled: !_guardando,
              decoration: const InputDecoration(
                labelText: 'Nombre *',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _apellidos,
              enabled: !_guardando,
              decoration: const InputDecoration(
                labelText: 'Apellidos',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _cinturon,
              onChanged: _guardando ? null : (v) => setState(() => _cinturon = v),
              decoration: const InputDecoration(
                labelText: 'Cinturón (opcional)',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'blanco', child: Text('Blanco')),
                DropdownMenuItem(value: 'azul', child: Text('Azul')),
                DropdownMenuItem(value: 'morado', child: Text('Morado')),
                DropdownMenuItem(value: 'marron', child: Text('Marrón')),
                DropdownMenuItem(value: 'negro', child: Text('Negro')),
              ],
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _guardando ? null : _guardar,
              child: _guardando
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }
}
