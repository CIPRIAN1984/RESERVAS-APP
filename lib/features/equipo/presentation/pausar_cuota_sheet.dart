import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/color_tokens.dart';
import '../../../core/models/profile.dart';
import '../../../core/utils/error_messages.dart';
import '../application/equipo_providers.dart';

/// Congelar una cuota (baja temporal, lesión...). Mientras dure, no cuenta
/// para reservar.
///
/// Sin fecha de reanudación queda pausada hasta que el Dueño la reanude a
/// mano; con fecha, se reanuda ella sola.
///
/// Devuelve `true` si se pausó.
Future<bool> mostrarPausarCuota(
  BuildContext context,
  Profile alumno,
  String suscripcionId,
) async {
  final hecho = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useRootNavigator: true,
    builder: (_) =>
        _PausarCuotaSheet(alumno: alumno, suscripcionId: suscripcionId),
  );
  return hecho ?? false;
}

class _PausarCuotaSheet extends ConsumerStatefulWidget {
  const _PausarCuotaSheet({required this.alumno, required this.suscripcionId});

  final Profile alumno;
  final String suscripcionId;

  @override
  ConsumerState<_PausarCuotaSheet> createState() => _PausarCuotaSheetState();
}

class _PausarCuotaSheetState extends ConsumerState<_PausarCuotaSheet> {
  bool _indefinida = true;
  DateTime? _hasta;
  bool _guardando = false;

  Future<void> _elegirFecha() async {
    final elegida = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now().add(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (elegida != null) setState(() => _hasta = elegida);
  }

  Future<void> _guardar() async {
    if (!_indefinida && _hasta == null) return;

    setState(() => _guardando = true);
    try {
      await ref
          .read(equipoRepositoryProvider)
          .pausarCuota(
            suscripcionId: widget.suscripcionId,
            hasta: _indefinida ? null : _hasta,
          );
      ref.invalidate(cuotasActivasProvider);
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(() => _guardando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              mensajeErrorAmigable(
                error,
                generico: 'No se ha podido pausar la cuota.',
              ),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          20 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Pausar cuota', style: t.titleLarge),
            const SizedBox(height: 4),
            Text(
              'Para ${widget.alumno.nombre}. Mientras esté pausada no podrá '
              'reservar, aunque siga dado de alta.',
              style: t.bodyMedium?.copyWith(color: AppColors.subtle),
            ),
            const SizedBox(height: 16),
            RadioGroup<bool>(
              groupValue: _indefinida,
              onChanged: (v) {
                if (_guardando || v == null) return;
                setState(() => _indefinida = v);
              },
              child: Column(
                children: [
                  RadioListTile<bool>(
                    value: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Indefinida'),
                    subtitle: const Text('Hasta que tú la reanudes'),
                  ),
                  RadioListTile<bool>(
                    value: false,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Hasta una fecha'),
                    subtitle: const Text('Se reanuda sola ese día'),
                  ),
                ],
              ),
            ),
            if (!_indefinida) ...[
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: _guardando ? null : _elegirFecha,
                child: Text(
                  _hasta == null
                      ? 'Elegir fecha de reanudación'
                      : DateFormat(
                          "d 'de' MMMM 'de' y",
                          'es_ES',
                        ).format(_hasta!),
                ),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: (_guardando || (!_indefinida && _hasta == null))
                  ? null
                  : _guardar,
              child: _guardando
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Pausar cuota'),
            ),
          ],
        ),
      ),
    );
  }
}
