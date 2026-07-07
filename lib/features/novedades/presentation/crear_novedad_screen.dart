import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/novedades_providers.dart';

class CrearNovedadScreen extends ConsumerStatefulWidget {
  const CrearNovedadScreen({
    required this.academiaId,
    required this.autorId,
    super.key,
  });

  final String academiaId;
  final String autorId;

  @override
  ConsumerState<CrearNovedadScreen> createState() => _CrearNovedadScreenState();
}

class _CrearNovedadScreenState extends ConsumerState<CrearNovedadScreen> {
  final _formKey = GlobalKey<FormState>();
  final _tituloController = TextEditingController();
  final _contenidoController = TextEditingController();
  bool _guardando = false;
  String? _error;

  @override
  void dispose() {
    _tituloController.dispose();
    _contenidoController.dispose();
    super.dispose();
  }

  Future<void> _publicar() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      await ref
          .read(novedadesRepositoryProvider)
          .crear(
            academiaId: widget.academiaId,
            autorId: widget.autorId,
            titulo: _tituloController.text.trim(),
            contenido: _contenidoController.text.trim(),
          );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = 'No se ha podido publicar la novedad.');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Publicar novedad')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _tituloController,
                  decoration: const InputDecoration(labelText: 'Título'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Obligatorio' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _contenidoController,
                  decoration: const InputDecoration(labelText: 'Contenido'),
                  maxLines: 6,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Obligatorio' : null,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _guardando ? null : _publicar,
                  child: _guardando
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Publicar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
