import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/tarifas_providers.dart';

class CrearTarifaScreen extends ConsumerStatefulWidget {
  const CrearTarifaScreen({required this.academiaId, super.key});

  final String academiaId;

  @override
  ConsumerState<CrearTarifaScreen> createState() => _CrearTarifaScreenState();
}

class _CrearTarifaScreenState extends ConsumerState<CrearTarifaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _descripcionController = TextEditingController();
  final _precioController = TextEditingController();
  String _periodicidad = 'mensual';
  bool _guardando = false;
  String? _error;

  @override
  void dispose() {
    _nombreController.dispose();
    _descripcionController.dispose();
    _precioController.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      await ref.read(tarifasRepositoryProvider).crearTarifa(
            academiaId: widget.academiaId,
            nombre: _nombreController.text.trim(),
            descripcion: _descripcionController.text.trim(),
            precio: num.parse(_precioController.text.trim()),
            periodicidad: _periodicidad,
          );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = 'No se ha podido crear la tarifa.');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nueva tarifa')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _nombreController,
                  decoration: const InputDecoration(labelText: 'Nombre'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Obligatorio' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descripcionController,
                  decoration: const InputDecoration(labelText: 'Descripción'),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _precioController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Precio (€)'),
                  validator: (v) => (num.tryParse(v ?? '') == null) ? 'Introduce un precio válido' : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _periodicidad,
                  decoration: const InputDecoration(labelText: 'Periodicidad'),
                  items: const [
                    DropdownMenuItem(value: 'mensual', child: Text('Mensual')),
                    DropdownMenuItem(value: 'trimestral', child: Text('Trimestral')),
                    DropdownMenuItem(value: 'anual', child: Text('Anual')),
                  ],
                  onChanged: (v) => setState(() => _periodicidad = v ?? _periodicidad),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ],
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _guardando ? null : _guardar,
                  child: _guardando
                      ? const SizedBox(
                          height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Crear tarifa'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
