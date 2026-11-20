import 'package:flutter/material.dart';
import 'package:itaca/app/theme/app_palette.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../shared/widgets/pantalla.dart';
import '../application/pagos_providers.dart';
import '../data/pago_tarjeta.dart';

/// Lo que el Dueño tiene que mirar de los pagos con tarjeta: cobrados sin
/// cuota activada, fallidos, abandonados o rechazados. Así un fallo de cobro
/// se ve aquí sin esperar a que un alumno lo cuente.
class PagosConProblemaSeccion extends ConsumerWidget {
  const PagosConProblemaSeccion({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pagos = ref.watch(pagosConProblemaProvider);
    // Riverpod reintenta solo y `.when` taparía el error con el cargador:
    // se mira `hasError` y `hasValue` a mano.
    if (pagos.hasError && !pagos.hasValue) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'No se han podido cargar los pagos con tarjeta.',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => ref.invalidate(pagosConProblemaProvider),
            child: const Text('Reintentar'),
          ),
        ],
      );
    }
    final lista = pagos.value;
    if (lista == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Pagos con tarjeta por revisar',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        if (lista.isEmpty)
          Text(
            'Ningún pago con problemas. Aquí saldrá cualquier pago cobrado '
            'sin cuota activada, fallido o abandonado.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: context.paleta.subtle),
          )
        else
          for (final pago in lista) _FilaPago(pago: pago),
      ],
    );
  }
}

class _FilaPago extends StatelessWidget {
  const _FilaPago({required this.pago});

  final PagoTarjeta pago;

  @override
  Widget build(BuildContext context) {
    final pastilla = switch (pago.estado) {
      'revisar' => PastillaEstado.error('Cobrado, sin cuota'),
      'fallido' => PastillaEstado.error('Fallido'),
      'expirado' => PastillaEstado.aviso('Abandonado'),
      _ => const PastillaEstado.aviso('Rechazado'),
    };
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              pago.alumno ?? 'Alumno',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Text(
              '${pago.importeEsperado.toStringAsFixed(2)} € · '
              '${DateFormat("d 'de' MMM, HH:mm", 'es_ES').format(pago.creado.toLocal())}',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: context.paleta.subtle),
            ),
            const SizedBox(height: 8),
            Align(alignment: Alignment.centerLeft, child: pastilla),
            if (pago.error != null) ...[
              const SizedBox(height: 8),
              Text(pago.error!, style: Theme.of(context).textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}
