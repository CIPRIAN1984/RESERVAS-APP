import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/color_tokens.dart';
import '../../../core/models/profile.dart';
import '../../../core/utils/error_messages.dart';
import '../../tarifas/application/tarifas_providers.dart';
import '../application/equipo_providers.dart';

/// Reconocer una cuota cobrada en mano.
///
/// Hace falta porque reservar plaza exige al Alumno una cuota con el pago
/// activo, y ese estado solo lo enciende el webhook de Stripe. Sin esto, y
/// mientras Stripe no esté conectado, ningún alumno podría reservar nunca.
///
/// Devuelve `true` si se activó la cuota.
Future<bool> mostrarDarCuota(BuildContext context, Profile alumno) async {
  final hecho = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    // Sin esto la hoja se abre en el navegador de dentro del armazón y solo
    // dispone del alto del cuerpo, sin contar la barra inferior. No era la
    // causa del fallo —lo era que el contenido no se podía desplazar— pero
    // así la hoja cuenta con la pantalla entera y hay que deslizar menos.
    useRootNavigator: true,
    builder: (_) => _DarCuotaSheet(alumno: alumno),
  );
  return hecho ?? false;
}

class _DarCuotaSheet extends ConsumerStatefulWidget {
  const _DarCuotaSheet({required this.alumno});

  final Profile alumno;

  @override
  ConsumerState<_DarCuotaSheet> createState() => _DarCuotaSheetState();
}

class _DarCuotaSheetState extends ConsumerState<_DarCuotaSheet> {
  String? _tarifaId;
  int _meses = 1;
  bool _guardando = false;

  DateTime get _hasta => DateTime.now().add(Duration(days: 30 * _meses));

  Future<void> _guardar() async {
    final tarifaId = _tarifaId;
    if (tarifaId == null) return;

    setState(() => _guardando = true);
    try {
      await ref
          .read(equipoRepositoryProvider)
          .activarCuotaEfectivo(
            alumnoId: widget.alumno.id,
            tarifaId: tarifaId,
            hasta: _hasta,
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
                generico: 'No se ha podido registrar la cuota.',
              ),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Solo tarifas activas: cobrar una retirada dejaría al alumno con una
    // cuota que ya no se ofrece.
    final tarifasAsync = ref.watch(tarifasProvider(true));
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
            Text('Cobro en efectivo', style: t.titleLarge),
            const SizedBox(height: 4),
            Text(
              'Para ${widget.alumno.nombre}. Queda registrado como cobrado '
              'en mano, no pasa por Stripe.',
              style: t.bodyMedium?.copyWith(color: AppColors.subtle),
            ),
            const SizedBox(height: 24),

            // Lo que puede crecer se desplaza; el botón se queda abajo,
            // siempre visible. Con muchas tarifas, si se desplazara todo,
            // «Registrar cobro» volvería a salirse de la pantalla.
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Tarifa', style: t.titleMedium),
                    const SizedBox(height: 8),
                    tarifasAsync.when(
                      loading: () => const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: LinearProgressIndicator(),
                      ),
                      error: (_, _) =>
                          const Text('No se han podido cargar las tarifas.'),
                      data: (tarifas) {
                        if (tarifas.isEmpty) {
                          return Text(
                            'Todavía no hay ninguna tarifa activa. Crea una en '
                            'Herramientas → Tarifas y planes.',
                            style: t.bodyMedium?.copyWith(
                              color: AppColors.subtle,
                            ),
                          );
                        }
                        return RadioGroup<String>(
                          groupValue: _tarifaId,
                          // RadioGroup exige un callback: se ignora el cambio
                          // mientras se guarda, en vez de quitarlo.
                          onChanged: (v) {
                            if (_guardando) return;
                            setState(() => _tarifaId = v);
                          },
                          child: Column(
                            children: [
                              for (final tarifa in tarifas)
                                RadioListTile<String>(
                                  value: tarifa.id,
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(tarifa.nombre),
                                  subtitle: Text(
                                    '${tarifa.precio.toStringAsFixed(2)} € · '
                                    '${tarifa.periodicidad}',
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 16),
                    Text('Cuánto ha pagado', style: t.titleMedium),
                    const SizedBox(height: 8),
                    SegmentedButton<int>(
                      // El tic de «seleccionado» roba ancho al texto y partía «1 mes»
                      // en dos líneas. El relleno negro ya indica cuál está elegido.
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(value: 1, label: Text('1 mes')),
                        ButtonSegment(value: 3, label: Text('3 meses')),
                        ButtonSegment(value: 6, label: Text('6 meses')),
                        ButtonSegment(value: 12, label: Text('1 año')),
                      ],
                      selected: {_meses},
                      onSelectionChanged: _guardando
                          ? null
                          : (s) => setState(() => _meses = s.first),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Podrá reservar hasta el '
                      '${DateFormat("d 'de' MMMM 'de' y", 'es_ES').format(_hasta)}.',
                      style: t.bodySmall?.copyWith(color: AppColors.subtle),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),
            FilledButton(
              onPressed: (_tarifaId == null || _guardando) ? null : _guardar,
              child: _guardando
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Registrar cobro'),
            ),
          ],
        ),
      ),
    );
  }
}
