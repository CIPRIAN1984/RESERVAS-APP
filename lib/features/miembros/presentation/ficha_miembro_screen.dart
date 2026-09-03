import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/color_tokens.dart';
import '../../../core/models/profile.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/pantalla.dart';
import '../application/miembros_providers.dart';
import 'miembros_screen.dart'
    show esInactivo, etiquetaCinturon, etiquetaInactividad;

/// Ficha de un alumno: cuánto lleva entrenando en su cinturón actual y
/// cuánto le falta para el siguiente — lo que Cipri pidió mirando la
/// pestaña «Promociones» de MAAT. El resto de la ficha (contacto,
/// documentos, notas, gráficas de actividad) queda para otra tanda: son
/// datos que hoy no guardamos.
class FichaMiembroScreen extends ConsumerWidget {
  const FichaMiembroScreen({required this.alumno, super.key});

  final Profile alumno;

  Future<void> _promover(
    BuildContext context,
    WidgetRef ref,
    String proximo,
  ) async {
    // OJO con el contexto: `showDialog` monta el diálogo en el navegador
    // raíz, pero `context` aquí es el de esta pantalla, que en la app real
    // cuelga del navegador anidado del armazón (el de la barra inferior).
    // Usar `context` en los botones cerraba la ficha por detrás y dejaba el
    // diálogo pegado en pantalla, sin devolver nunca la respuesta: promover
    // no llegaba a ejecutarse jamás. Hay que usar el contexto del propio
    // diálogo. (Lo cazó Cipri probando en el móvil, 02/09/2026.)
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (contextoDialogo) => AlertDialog(
        title: const Text('Promover a un nuevo cinturón'),
        content: Text(
          '¿Pasar a ${alumno.nombreCompleto} de '
          '${etiquetaCinturon(alumno.cinturon ?? 'blanco')} a '
          '${etiquetaCinturon(proximo)}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(contextoDialogo).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(contextoDialogo).pop(true),
            child: const Text('Promover'),
          ),
        ],
      ),
    );
    if (confirmar != true || !context.mounted) return;

    try {
      await ref
          .read(miembrosRepositoryProvider)
          .promoverCinturon(alumnoId: alumno.id, nuevoCinturon: proximo);
      if (!context.mounted) return;
      ref.invalidate(alumnosMiembrosProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${alumno.nombreCompleto} ya es ${etiquetaCinturon(proximo)}.',
          ),
        ),
      );
      Navigator.of(context).pop();
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se ha podido promover al alumno.')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progresoAsync = ref.watch(
      progresoCinturonProvider((
        alumnoId: alumno.id,
        cinturon: alumno.cinturon,
        fechaInicioCinturon: alumno.fechaInicioCinturon,
      )),
    );
    // Misma consulta que ya pide la lista de Miembros (una por academia,
    // no una por ficha): si se llega aquí desde la lista, el provider ya
    // está en caché y esto no repite ningún viaje al servidor.
    final ultima = ref
        .watch(ultimaAsistenciaMiembrosProvider)
        .value?[alumno.id];

    return Scaffold(
      appBar: AppBar(title: Text(alumno.nombreCompleto)),
      body: SafeArea(
        child: progresoAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, st) => const EmptyState(
            icon: Icons.error_outline,
            message: 'No se ha podido calcular el progreso.',
          ),
          data: (progreso) => SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _TarjetaRango(
                  actual: alumno.cinturon ?? 'blanco',
                  proximo: progreso.proximoCinturon,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    esInactivo(ultima)
                        ? PastillaEstado.aviso(etiquetaInactividad(ultima))
                        : PastillaEstado.exito(etiquetaInactividad(ultima)),
                    if (progreso.listoParaGraduarse)
                      const PastillaEstado.exito('Listo para graduarse'),
                  ],
                ),
                const SizedBox(height: 20),
                if (progreso.proximoCinturon == null)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(18),
                      child: Text(
                        'Ya tiene el cinturón más alto que gestionamos aquí.',
                      ),
                    ),
                  )
                else ...[
                  _AnilloProgreso(fraccion: progreso.fraccion ?? 0),
                  const SizedBox(height: 16),
                  Text(
                    'Ha completado ${progreso.asistencias} de las '
                    '${progreso.requeridas} clases totales requeridas para '
                    'el siguiente cinturón.',
                    textAlign: TextAlign.center,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: AppColors.subtle),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () =>
                        _promover(context, ref, progreso.proximoCinturon!),
                    child: const Text('Promover a un nuevo cinturón'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

extension on Profile {
  String get nombreCompleto =>
      [nombre, apellidos].whereType<String>().join(' ');
}

class _TarjetaRango extends StatelessWidget {
  const _TarjetaRango({required this.actual, required this.proximo});

  final String actual;
  final String? proximo;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Rango actual', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(child: _Cinturon(cinturon: actual)),
                if (proximo != null) ...[
                  const Icon(Icons.arrow_forward, color: AppColors.subtle),
                  Expanded(child: _Cinturon(cinturon: proximo)),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Cinturon extends StatelessWidget {
  const _Cinturon({required this.cinturon});

  final String? cinturon;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        PuntoCinturon(cinturon, tamano: 28),
        const SizedBox(height: 6),
        Text(
          etiquetaCinturon(cinturon ?? 'blanco'),
          style: Theme.of(context).textTheme.labelSmall,
        ),
      ],
    );
  }
}

class _AnilloProgreso extends StatelessWidget {
  const _AnilloProgreso({required this.fraccion});

  final double fraccion;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 160,
        height: 160,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 160,
              height: 160,
              child: CircularProgressIndicator(
                value: fraccion,
                strokeWidth: 12,
                strokeCap: StrokeCap.round,
                backgroundColor: AppColors.line,
                valueColor: const AlwaysStoppedAnimation(AppColors.ink),
              ),
            ),
            Text(
              '${(fraccion * 100).round()}%',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
    );
  }
}
