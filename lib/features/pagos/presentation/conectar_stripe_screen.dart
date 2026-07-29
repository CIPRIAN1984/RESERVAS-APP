import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme/color_tokens.dart';
import '../../../core/auth/auth_state.dart';
import '../../../core/utils/error_messages.dart';
import '../application/pagos_providers.dart';

class ConectarStripeScreen extends ConsumerStatefulWidget {
  const ConectarStripeScreen({super.key});

  @override
  ConsumerState<ConectarStripeScreen> createState() =>
      _ConectarStripeScreenState();
}

class _ConectarStripeScreenState extends ConsumerState<ConectarStripeScreen> {
  bool _cargando = false;
  String? _error;

  Future<void> _conectar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final url = await ref
          .read(pagosRepositoryProvider)
          .obtenerUrlOnboarding();
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      setState(() => _error = mensajeErrorAmigable(e));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _refrescar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      await ref.read(pagosRepositoryProvider).refrescarEstado();
      ref.invalidate(currentAcademiaProvider);
    } catch (e) {
      setState(() => _error = mensajeErrorAmigable(e));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final academiaAsync = ref.watch(currentAcademiaProvider);

    return Scaffold(
      body: SafeArea(
        child: academiaAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, st) => Center(
            child: Text(
              'No se ha podido cargar el estado de cobros.',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
          data: (academia) {
            if (academia == null) {
              return const Center(child: Text('No hay academia asociada.'));
            }
            final estado = academia.stripeOnboardingStatus;
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_iconoPara(estado), size: 56, color: _colorPara(estado)),
                  const SizedBox(height: 20),
                  Text(
                    _tituloPara(estado),
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _descripcionPara(estado),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.subtle,
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _cargando ? null : _conectar,
                    child: _cargando
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            estado == 'not_started'
                                ? 'Conectar con Stripe'
                                : 'Continuar configuración',
                          ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _cargando ? null : _refrescar,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Comprobar estado'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  IconData _iconoPara(String estado) => switch (estado) {
    'complete' => Icons.check_circle_outline,
    'pending' => Icons.hourglass_top_outlined,
    _ => Icons.credit_card_outlined,
  };

  Color _colorPara(String estado) => switch (estado) {
    'complete' => AppColors.successFg,
    'pending' => AppColors.warningFg,
    _ => AppColors.subtle,
  };

  String _tituloPara(String estado) => switch (estado) {
    'complete' => 'Cobros activados',
    'pending' => 'Configuración pendiente',
    _ => 'Conecta tu cuenta de Stripe',
  };

  String _descripcionPara(String estado) => switch (estado) {
    'complete' =>
      'Tu academia ya puede cobrar tarifas y ventas de la tienda directamente en tu propia cuenta de Stripe.',
    'pending' =>
      'Empezaste a conectar tu cuenta de Stripe pero faltan datos por completar. Continúa la configuración para poder cobrar.',
    _ =>
      'Para poder cobrar las cuotas y la tienda directamente en tu cuenta, conecta tu Stripe. El dinero va siempre a tu cuenta, ITACA nunca lo retiene.',
  };
}
