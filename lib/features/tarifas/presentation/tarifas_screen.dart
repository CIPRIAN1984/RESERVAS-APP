import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_stripe/flutter_stripe.dart' hide Card;

import '../../../../app/app_mode.dart';
import '../../../app/theme/color_tokens.dart';
import '../../../core/auth/auth_state.dart';
import '../../../core/utils/error_messages.dart';
import '../application/tarifas_providers.dart';
import '../data/tarifa.dart';
import 'crear_tarifa_screen.dart';

class TarifasScreen extends ConsumerWidget {
  const TarifasScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider).value;
    final userId = ref.watch(currentUserIdProvider);

    if (profile == null || profile.academiaId == null || userId == null) {
      return const Center(child: CircularProgressIndicator());
    }

    // En modo Entrenamiento se ve «mi cuota»; en modo Gestor, el catálogo
    // de tarifas de la academia.
    final puedeGestionar = ref.watch(enModoGestionProvider);

    return puedeGestionar
        ? _TarifasGestionView(academiaId: profile.academiaId!)
        : _TarifasAlumnoView(academiaId: profile.academiaId!, alumnoId: userId);
  }
}

class _TarifasAlumnoView extends ConsumerStatefulWidget {
  const _TarifasAlumnoView({required this.academiaId, required this.alumnoId});

  final String academiaId;
  final String alumnoId;

  @override
  ConsumerState<_TarifasAlumnoView> createState() => _TarifasAlumnoViewState();
}

class _TarifasAlumnoViewState extends ConsumerState<_TarifasAlumnoView> {
  String? _procesandoTarifaId;
  bool _cancelando = false;

  Future<void> _suscribirse(Tarifa tarifa) async {
    final academia = ref.read(currentAcademiaProvider).value;
    if (academia == null || !academia.stripeChargesEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Esta academia todavía no ha configurado los cobros.'),
        ),
      );
      return;
    }

    setState(() => _procesandoTarifaId = tarifa.id);
    final repo = ref.read(tarifasRepositoryProvider);
    try {
      final pago = await repo.iniciarSuscripcion(tarifa.id);

      Stripe.stripeAccountId = pago.stripeAccountId;
      await Stripe.instance.applySettings();

      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: pago.clientSecret,
          merchantDisplayName: 'I+',
        ),
      );
      await Stripe.instance.presentPaymentSheet();

      ref.invalidate(suscripcionActivaProvider(widget.alumnoId));
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Suscrito a ${tarifa.nombre}.')));
      }
    } on StripeException catch (e) {
      if (e.error.code == FailureCode.Canceled) return;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('El pago no se ha podido completar.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              mensajeErrorAmigable(
                e,
                generico: 'No se ha podido iniciar la suscripción.',
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _procesandoTarifaId = null);
    }
  }

  Future<void> _cancelar(String suscripcionId) async {
    setState(() => _cancelando = true);
    try {
      await ref
          .read(tarifasRepositoryProvider)
          .cancelarSuscripcion(suscripcionId);
      ref.invalidate(suscripcionActivaProvider(widget.alumnoId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se ha podido cancelar la suscripción.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _cancelando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final suscripcionAsync = ref.watch(
      suscripcionActivaProvider(widget.alumnoId),
    );
    final tarifasAsync = ref.watch(tarifasProvider(true));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Tu tarifa actual',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        suscripcionAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, st) => Text(
            'No se ha podido cargar tu suscripción.',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          data: (suscripcion) {
            if (suscripcion == null) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'No tienes ninguna suscripción activa todavía.',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: AppColors.subtle),
                  ),
                ),
              );
            }
            final enProceso = suscripcion.estado == 'pendiente_pago';
            return Card(
              color: AppColors.ink.withValues(alpha: 0.12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      suscripcion.tarifaNombre ?? 'Tarifa',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${suscripcion.tarifaPrecio?.toStringAsFixed(2) ?? '-'} € ${etiquetasPeriodicidad[suscripcion.tarifaPeriodicidad] ?? ''}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    if (enProceso) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Pago en proceso...',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.subtle,
                        ),
                      ),
                    ] else ...[
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton(
                          onPressed: _cancelando
                              ? null
                              : () => _cancelar(suscripcion.id),
                          child: _cancelando
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Cancelar suscripción'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 24),
        Text(
          'Tarifas disponibles',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        tarifasAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, st) => Text(
            'No se han podido cargar las tarifas.',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          data: (tarifas) {
            final actualId = suscripcionAsync.value?.tarifaId;
            if (tarifas.isEmpty) {
              return Text(
                'Tu academia todavía no tiene tarifas publicadas.',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppColors.subtle),
              );
            }
            return Column(
              children: [
                for (final tarifa in tarifas)
                  Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      title: Text(tarifa.nombre),
                      subtitle: Text(
                        '${tarifa.precio.toStringAsFixed(2)} € ${etiquetasPeriodicidad[tarifa.periodicidad] ?? ''}'
                        '${tarifa.descripcion != null ? '\n${tarifa.descripcion}' : ''}',
                      ),
                      isThreeLine: tarifa.descripcion != null,
                      trailing: tarifa.id == actualId
                          ? const Chip(label: Text('Actual'))
                          : _procesandoTarifaId == tarifa.id
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : OutlinedButton(
                              onPressed: () => _suscribirse(tarifa),
                              child: const Text('Suscribirse'),
                            ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _TarifasGestionView extends ConsumerWidget {
  const _TarifasGestionView({required this.academiaId});

  final String academiaId;

  Future<void> _alternarActivo(WidgetRef ref, Tarifa tarifa) async {
    await ref
        .read(tarifasRepositoryProvider)
        .alternarActivo(tarifa.id, !tarifa.activo);
    ref.invalidate(tarifasProvider(false));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tarifasAsync = ref.watch(tarifasProvider(false));

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => CrearTarifaScreen(academiaId: academiaId),
            ),
          );
          ref.invalidate(tarifasProvider(false));
        },
        icon: const Icon(Icons.add),
        label: const Text('Tarifa'),
      ),
      body: tarifasAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(
          child: Text(
            'No se han podido cargar las tarifas.',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
        data: (tarifas) {
          if (tarifas.isEmpty) {
            return Center(
              child: Text(
                'Todavía no hay tarifas creadas.',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppColors.subtle),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: tarifas.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final tarifa = tarifas[index];
              return Card(
                child: ListTile(
                  title: Text(tarifa.nombre),
                  subtitle: Text(
                    '${tarifa.precio.toStringAsFixed(2)} € ${etiquetasPeriodicidad[tarifa.periodicidad] ?? ''}',
                  ),
                  trailing: Switch(
                    value: tarifa.activo,
                    onChanged: (_) => _alternarActivo(ref, tarifa),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
