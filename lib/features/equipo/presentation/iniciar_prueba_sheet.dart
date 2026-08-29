import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/color_tokens.dart';
import '../../../core/models/profile.dart';
import '../../../core/utils/error_messages.dart';
import '../../tarifas/application/tarifas_providers.dart';
import '../application/equipo_providers.dart';

/// Dejar probar 1 día sin cobrar todavía.
///
/// Dura siempre 24 horas y caduca sola: no hay que acordarse de retirarla si
/// el alumno no sigue. Sigue haciendo falta elegir tarifa, para saber qué se
/// le cobraría si se queda.
///
/// Devuelve `true` si se inició la prueba.
Future<bool> mostrarIniciarPrueba(BuildContext context, Profile alumno) async {
  final hecho = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useRootNavigator: true,
    builder: (_) => _IniciarPruebaSheet(alumno: alumno),
  );
  return hecho ?? false;
}

class _IniciarPruebaSheet extends ConsumerStatefulWidget {
  const _IniciarPruebaSheet({required this.alumno});

  final Profile alumno;

  @override
  ConsumerState<_IniciarPruebaSheet> createState() =>
      _IniciarPruebaSheetState();
}

class _IniciarPruebaSheetState extends ConsumerState<_IniciarPruebaSheet> {
  String? _tarifaId;
  bool _guardando = false;

  Future<void> _guardar() async {
    final tarifaId = _tarifaId;
    if (tarifaId == null) return;

    setState(() => _guardando = true);
    try {
      await ref
          .read(equipoRepositoryProvider)
          .iniciarPrueba(alumnoId: widget.alumno.id, tarifaId: tarifaId);
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
                generico: 'No se ha podido iniciar la prueba.',
              ),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
            Text('Iniciar prueba', style: t.titleLarge),
            const SizedBox(height: 4),
            Text(
              'Para ${widget.alumno.nombre}. Podrá reservar durante 1 día '
              'sin que le cobres todavía; pasado ese día deja de contar sola.',
              style: t.bodyMedium?.copyWith(color: AppColors.subtle),
            ),
            const SizedBox(height: 24),

            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Tarifa a la que probaría', style: t.titleMedium),
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
                  : const Text('Iniciar prueba de 1 día'),
            ),
          ],
        ),
      ),
    );
  }
}
