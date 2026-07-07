import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/progreso_providers.dart';
import '../data/tecnica.dart';

class CrearTecnicaScreen extends ConsumerStatefulWidget {
  const CrearTecnicaScreen({required this.academiaId, super.key});

  final String academiaId;

  @override
  ConsumerState<CrearTecnicaScreen> createState() => _CrearTecnicaScreenState();
}

class _CrearTecnicaScreenState extends ConsumerState<CrearTecnicaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _descripcionController = TextEditingController();
  final _ordenController = TextEditingController(text: '0');
  String _cinturon = ordenCinturones.first;
  bool _guardando = false;
  String? _error;

  @override
  void dispose() {
    _nombreController.dispose();
    _descripcionController.dispose();
    _ordenController.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      await ref.read(progresoRepositoryProvider).crearTecnica(
            academiaId: widget.academiaId,
            cinturon: _cinturon,
            nombre: _nombreController.text.trim(),
            descripcion: _descripcionController.text.trim(),
            orden: int.tryParse(_ordenController.text.trim()) ?? 0,
          );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = 'No se ha podido crear la técnica.');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nueva técnica')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _cinturon,
                  decoration: const InputDecoration(labelText: 'Cinturón'),
                  items: [
                    for (final c in ordenCinturones)
                      DropdownMenuItem(value: c, child: Text(nombreCinturones[c] ?? c)),
                  ],
                  onChanged: (v) => setState(() => _cinturon = v ?? _cinturon),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nombreController,
                  decoration: const InputDecoration(labelText: 'Nombre de la técnica'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Obligatorio' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descripcionController,
                  decoration: const InputDecoration(labelText: 'Descripción'),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _ordenController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Orden dentro del cinturón'),
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
                      : const Text('Crear técnica'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
