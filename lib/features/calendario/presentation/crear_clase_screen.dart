import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../application/clases_providers.dart';

class CrearClaseScreen extends ConsumerStatefulWidget {
  const CrearClaseScreen({required this.academiaId, required this.profesorId, super.key});

  final String academiaId;
  final String profesorId;

  @override
  ConsumerState<CrearClaseScreen> createState() => _CrearClaseScreenState();
}

class _CrearClaseScreenState extends ConsumerState<CrearClaseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _tituloController = TextEditingController();
  final _descripcionController = TextEditingController();
  final _aforoController = TextEditingController(text: '15');
  final _numeroSemanasController = TextEditingController(text: '4');

  DateTime _fecha = DateTime.now();
  TimeOfDay _horaInicio = const TimeOfDay(hour: 19, minute: 0);
  TimeOfDay _horaFin = const TimeOfDay(hour: 20, minute: 0);
  bool _periodica = false;
  bool _guardando = false;
  String? _error;

  @override
  void dispose() {
    _tituloController.dispose();
    _descripcionController.dispose();
    _aforoController.dispose();
    _numeroSemanasController.dispose();
    super.dispose();
  }

  DateTime _combinar(DateTime fecha, TimeOfDay hora) =>
      DateTime(fecha.year, fecha.month, fecha.day, hora.hour, hora.minute);

  Future<void> _elegirFecha() async {
    final elegida = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (elegida != null) setState(() => _fecha = elegida);
  }

  Future<void> _elegirHora({required bool esInicio}) async {
    final elegida = await showTimePicker(
      context: context,
      initialTime: esInicio ? _horaInicio : _horaFin,
    );
    if (elegida != null) {
      setState(() => esInicio ? _horaInicio = elegida : _horaFin = elegida);
    }
  }

  Future<void> _guardar() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final inicio = _combinar(_fecha, _horaInicio);
    final fin = _combinar(_fecha, _horaFin);
    if (!fin.isAfter(inicio)) {
      setState(() => _error = 'La hora de fin debe ser posterior a la de inicio.');
      return;
    }

    final repeticiones = _periodica ? int.parse(_numeroSemanasController.text.trim()) : 1;

    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      final repo = ref.read(clasesRepositoryProvider);
      for (var i = 0; i < repeticiones; i++) {
        final desplazamiento = Duration(days: 7 * i);
        await repo.crearClase(
          academiaId: widget.academiaId,
          profesorId: widget.profesorId,
          titulo: _tituloController.text.trim(),
          descripcion: _descripcionController.text.trim(),
          fechaHoraInicio: inicio.add(desplazamiento),
          fechaHoraFin: fin.add(desplazamiento),
          aforoMaximo: int.parse(_aforoController.text.trim()),
        );
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = 'No se ha podido crear la clase.');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final formatoFecha = DateFormat.yMMMMd('es_ES');
    return Scaffold(
      appBar: AppBar(title: const Text('Crear clase')),
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
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Obligatorio' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descripcionController,
                  decoration: const InputDecoration(labelText: 'Descripción'),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Fecha'),
                  subtitle: Text(formatoFecha.format(_fecha)),
                  trailing: const Icon(Icons.calendar_month_outlined),
                  onTap: _elegirFecha,
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Hora de inicio'),
                  subtitle: Text(_horaInicio.format(context)),
                  trailing: const Icon(Icons.schedule_outlined),
                  onTap: () => _elegirHora(esInicio: true),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Hora de fin'),
                  subtitle: Text(_horaFin.format(context)),
                  trailing: const Icon(Icons.schedule_outlined),
                  onTap: () => _elegirHora(esInicio: false),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _aforoController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Aforo máximo'),
                  validator: (v) {
                    final n = int.tryParse(v ?? '');
                    return (n == null || n <= 0) ? 'Introduce un número válido' : null;
                  },
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Clase periódica'),
                  subtitle: const Text('Repite esta clase cada semana en el mismo día y hora'),
                  value: _periodica,
                  onChanged: (v) => setState(() => _periodica = v),
                ),
                if (_periodica) ...[
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _numeroSemanasController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Número de semanas'),
                    validator: (v) {
                      if (!_periodica) return null;
                      final n = int.tryParse(v ?? '');
                      return (n == null || n <= 0 || n > 52) ? 'Introduce entre 1 y 52' : null;
                    },
                  ),
                ],
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
                      : Text(_periodica ? 'Crear clases' : 'Crear clase'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
