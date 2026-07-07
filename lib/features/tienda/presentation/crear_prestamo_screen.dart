import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/tienda_providers.dart';
import '../data/producto.dart';
import '../data/tienda_repository.dart';

class CrearPrestamoScreen extends ConsumerStatefulWidget {
  const CrearPrestamoScreen({
    required this.academiaId,
    required this.gestionadoPor,
    super.key,
  });

  final String academiaId;
  final String gestionadoPor;

  @override
  ConsumerState<CrearPrestamoScreen> createState() =>
      _CrearPrestamoScreenState();
}

class _CrearPrestamoScreenState extends ConsumerState<CrearPrestamoScreen> {
  final _descripcionController = TextEditingController();
  late Future<List<AlumnoOption>> _alumnosFuture;
  late Future<List<Producto>> _productosFuture;
  String? _alumnoSeleccionado;
  String? _productoSeleccionado;
  bool _guardando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _alumnosFuture = ref
        .read(tiendaRepositoryProvider)
        .listarAlumnos(widget.academiaId);
    _productosFuture = ref.read(tiendaRepositoryProvider).listarProductos();
  }

  @override
  void dispose() {
    _descripcionController.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (_alumnoSeleccionado == null) {
      setState(() => _error = 'Selecciona un alumno.');
      return;
    }
    if (_productoSeleccionado == null &&
        _descripcionController.text.trim().isEmpty) {
      setState(
        () => _error = 'Indica un producto del catálogo o una descripción.',
      );
      return;
    }
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      await ref
          .read(tiendaRepositoryProvider)
          .crearPrestamo(
            alumnoId: _alumnoSeleccionado!,
            productoId: _productoSeleccionado,
            descripcion: _descripcionController.text.trim().isEmpty
                ? null
                : _descripcionController.text.trim(),
            gestionadoPor: widget.gestionadoPor,
          );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = 'No se ha podido registrar el préstamo.');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nuevo préstamo')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FutureBuilder<List<AlumnoOption>>(
                future: _alumnosFuture,
                builder: (context, snapshot) {
                  final alumnos = snapshot.data ?? [];
                  return DropdownButtonFormField<String>(
                    initialValue: _alumnoSeleccionado,
                    decoration: const InputDecoration(labelText: 'Alumno'),
                    items: [
                      for (final a in alumnos)
                        DropdownMenuItem(value: a.id, child: Text(a.nombre)),
                    ],
                    onChanged: (v) => setState(() => _alumnoSeleccionado = v),
                  );
                },
              ),
              const SizedBox(height: 16),
              FutureBuilder<List<Producto>>(
                future: _productosFuture,
                builder: (context, snapshot) {
                  final productos = snapshot.data ?? [];
                  return DropdownButtonFormField<String>(
                    initialValue: _productoSeleccionado,
                    decoration: const InputDecoration(
                      labelText: 'Producto del catálogo (opcional)',
                    ),
                    items: [
                      for (final p in productos)
                        DropdownMenuItem(value: p.id, child: Text(p.nombre)),
                    ],
                    onChanged: (v) => setState(() => _productoSeleccionado = v),
                  );
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _descripcionController,
                decoration: const InputDecoration(
                  labelText: 'Descripción (si no es un producto del catálogo)',
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _guardando ? null : _guardar,
                child: _guardando
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Registrar préstamo'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
