import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/error_messages.dart';
import '../application/horario_providers.dart';
import '../data/plantilla_clase.dart';

/// Crear un hueco fijo del horario, o **editar uno que ya existe**.
///
/// Misma pantalla para las dos cosas, como ya hace `CrearTarifaScreen` con
/// las tarifas: los campos son los mismos.
class CrearPlantillaScreen extends ConsumerStatefulWidget {
  const CrearPlantillaScreen({
    required this.academiaId,
    required this.profesorId,
    this.plantilla,
    super.key,
  });

  final String academiaId;
  final String profesorId;

  /// Si viene, se edita esta; si no, se crea una nueva.
  final PlantillaClase? plantilla;

  @override
  ConsumerState<CrearPlantillaScreen> createState() =>
      _CrearPlantillaScreenState();
}

class _CrearPlantillaScreenState extends ConsumerState<CrearPlantillaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _tituloController = TextEditingController();
  final _descripcionController = TextEditingController();
  final _aforoController = TextEditingController(text: '15');
  late int _diaSemana;
  late TimeOfDay _horaInicio;
  int _duracionMin = 60;
  bool _guardando = false;
  String? _error;

  bool get _editando => widget.plantilla != null;

  @override
  void initState() {
    super.initState();
    final p = widget.plantilla;
    _diaSemana = p?.diaSemana ?? 1; // por defecto, lunes
    if (p != null) {
      _tituloController.text = p.titulo;
      _descripcionController.text = p.descripcion ?? '';
      _aforoController.text = p.aforoMaximo.toString();
      _duracionMin = p.duracionMin;
      final partes = p.horaInicio.split(':');
      _horaInicio = TimeOfDay(
        hour: int.parse(partes[0]),
        minute: int.parse(partes[1]),
      );
    } else {
      _horaInicio = const TimeOfDay(hour: 19, minute: 0);
    }
  }

  @override
  void dispose() {
    _tituloController.dispose();
    _descripcionController.dispose();
    _aforoController.dispose();
    super.dispose();
  }

  Future<void> _elegirHora() async {
    final elegida = await showTimePicker(
      context: context,
      initialTime: _horaInicio,
    );
    if (elegida != null) setState(() => _horaInicio = elegida);
  }

  String get _horaInicioTexto =>
      '${_horaInicio.hour.toString().padLeft(2, '0')}:'
      '${_horaInicio.minute.toString().padLeft(2, '0')}';

  Future<void> _guardar() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _guardando = true;
      _error = null;
    });
    final descripcion = _descripcionController.text.trim();
    try {
      final repo = ref.read(horarioRepositoryProvider);
      if (_editando) {
        await repo.editarPlantilla(
          plantillaId: widget.plantilla!.id,
          titulo: _tituloController.text.trim(),
          descripcion: descripcion.isEmpty ? null : descripcion,
          diaSemana: _diaSemana,
          horaInicio: _horaInicioTexto,
          duracionMin: _duracionMin,
          aforoMaximo: int.parse(_aforoController.text.trim()),
        );
      } else {
        await repo.crearPlantilla(
          academiaId: widget.academiaId,
          profesorId: widget.profesorId,
          titulo: _tituloController.text.trim(),
          descripcion: descripcion.isEmpty ? null : descripcion,
          diaSemana: _diaSemana,
          horaInicio: _horaInicioTexto,
          duracionMin: _duracionMin,
          aforoMaximo: int.parse(_aforoController.text.trim()),
        );
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(
        () => _error = mensajeErrorAmigable(
          e,
          generico: _editando
              ? 'No se ha podido guardar los cambios.'
              : 'No se ha podido crear el hueco del horario.',
        ),
      );
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_editando ? 'Editar horario fijo' : 'Nuevo horario fijo'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!_editando)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      'Esto se repite cada semana solo, sin que tengas que '
                      'volver a crearlo. Si un día concreto hay que '
                      'cambiarlo o cancelarlo, se hace desde esa clase en '
                      'el calendario — esto solo decide el hueco fijo.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                  ),
                TextFormField(
                  controller: _tituloController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre de la clase',
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Obligatorio' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descripcionController,
                  decoration: const InputDecoration(labelText: 'Descripción'),
                  maxLines: 2,
                ),
                const SizedBox(height: 20),
                Text(
                  'Día de la semana',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final dia in diasSemana)
                      ChoiceChip(
                        label: Text(nombresDiasCortos[dia]!),
                        selected: _diaSemana == dia,
                        onSelected: (_) => setState(() => _diaSemana = dia),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _elegirHora,
                        child: Text('Empieza a las $_horaInicioTexto'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  initialValue: _duracionMin,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Duración'),
                  items: const [
                    DropdownMenuItem(value: 30, child: Text('30 minutos')),
                    DropdownMenuItem(value: 45, child: Text('45 minutos')),
                    DropdownMenuItem(value: 60, child: Text('1 hora')),
                    DropdownMenuItem(value: 75, child: Text('1 hora y cuarto')),
                    DropdownMenuItem(value: 90, child: Text('1 hora y media')),
                    DropdownMenuItem(value: 120, child: Text('2 horas')),
                  ],
                  onChanged: (v) =>
                      setState(() => _duracionMin = v ?? _duracionMin),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _aforoController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Aforo máximo'),
                  validator: (v) {
                    final n = int.tryParse((v ?? '').trim());
                    return (n == null || n < 1)
                        ? 'Introduce un número válido'
                        : null;
                  },
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
                FilledButton(
                  onPressed: _guardando ? null : _guardar,
                  child: _guardando
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          _editando ? 'Guardar cambios' : 'Crear horario fijo',
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
