import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/color_tokens.dart';
import '../../../core/auth/auth_state.dart';
import '../application/configuracion_reservas_providers.dart';
import '../data/configuracion_reservas.dart';

class AjustesReservasScreen extends ConsumerWidget {
  const AjustesReservasScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider).value;
    final academiaId = profile?.academiaId;
    if (academiaId == null) {
      return const Center(child: Text('No se ha encontrado la academia.'));
    }

    final configuracion = ref.watch(configuracionReservasProvider(academiaId));
    return configuracion.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('No se han podido cargar los ajustes.'),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () =>
                  ref.invalidate(configuracionReservasProvider(academiaId)),
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
      data: (data) =>
          _ConfiguracionForm(academiaId: academiaId, configuracion: data),
    );
  }
}

class _ConfiguracionForm extends ConsumerStatefulWidget {
  const _ConfiguracionForm({
    required this.academiaId,
    required this.configuracion,
  });

  final String academiaId;
  final ConfiguracionReservas configuracion;

  @override
  ConsumerState<_ConfiguracionForm> createState() => _ConfiguracionFormState();
}

class _ConfiguracionFormState extends ConsumerState<_ConfiguracionForm> {
  late bool _listaEsperaActiva;
  late String _zonaHoraria;
  late final TextEditingController _horasController;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _listaEsperaActiva = widget.configuracion.listaEsperaActiva;
    _zonaHoraria = widget.configuracion.zonaHoraria;
    _horasController = TextEditingController(
      text: widget.configuracion.cancelacionLimiteHoras.toString(),
    );
  }

  @override
  void dispose() {
    _horasController.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final horas = int.tryParse(_horasController.text.trim());
    if (horas == null || horas < 0 || horas > 168) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Introduce un límite entre 0 y 168 horas.'),
        ),
      );
      return;
    }

    setState(() => _guardando = true);
    try {
      await ref
          .read(configuracionReservasRepositoryProvider)
          .actualizar(
            academiaId: widget.academiaId,
            listaEsperaActiva: _listaEsperaActiva,
            cancelacionLimiteMinutos: horas * 60,
            zonaHoraria: _zonaHoraria,
          );
      ref.invalidate(configuracionReservasProvider(widget.academiaId));
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Ajustes guardados.')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se han podido guardar los ajustes.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Automatización de plazas',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(
          'Estas reglas se aplican automáticamente a todas las clases.',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 20),
        Card(
          child: SwitchListTile(
            value: _listaEsperaActiva,
            onChanged: _guardando
                ? null
                : (value) {
                    setState(() => _listaEsperaActiva = value);
                  },
            title: const Text('Lista de espera automática'),
            subtitle: const Text(
              'Si una clase está llena, la siguiente persona entra en cola y '
              'recibe la plaza automáticamente cuando alguien cancela.',
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cancelación tardía',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _horasController,
                  enabled: !_guardando,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Horas antes de la clase',
                    helperText:
                        'La plaza siempre se libera; la baja queda marcada '
                        'como tardía dentro de este margen.',
                    suffixText: 'h',
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: DropdownButtonFormField<String>(
              initialValue: _zonaHoraria,
              decoration: const InputDecoration(
                labelText: 'Zona horaria',
                helperText:
                    'Mantiene la hora local al cambiar entre verano e invierno.',
              ),
              items: const [
                DropdownMenuItem(
                  value: 'Europe/Madrid',
                  child: Text('Península · Europe/Madrid'),
                ),
                DropdownMenuItem(
                  value: 'Atlantic/Canary',
                  child: Text('Canarias · Atlantic/Canary'),
                ),
              ],
              onChanged: _guardando
                  ? null
                  : (value) {
                      if (value != null) {
                        setState(() => _zonaHoraria = value);
                      }
                    },
            ),
          ),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: _guardando ? null : _guardar,
          icon: _guardando
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_outlined),
          label: Text(_guardando ? 'Guardando…' : 'Guardar ajustes'),
        ),
      ],
    );
  }
}
