import 'dart:async';

import 'package:flutter/material.dart';
import 'package:itaca/app/theme/app_palette.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/auth/auth_state.dart';
import '../application/pagos_providers.dart';

/// A donde se vuelve tras la página de pago de Stripe.
///
/// **No activa nada**: la cuota la activa el servidor cuando Stripe confirma
/// el cobro, aunque esta pantalla ni se llegue a abrir. Aquí solo se enseña
/// cómo va, y se le pide al servidor que lo compruebe con Stripe por si el
/// aviso tarda.
class PagoResultadoScreen extends ConsumerStatefulWidget {
  const PagoResultadoScreen({
    super.key,
    required this.pagoId,
    this.cancelado = false,
    this.intervalo = const Duration(seconds: 3),
    this.intentosMaximos = 20,
  });

  final String pagoId;
  final bool cancelado;
  final Duration intervalo;
  final int intentosMaximos;

  @override
  ConsumerState<PagoResultadoScreen> createState() =>
      _PagoResultadoScreenState();
}

class _PagoResultadoScreenState extends ConsumerState<PagoResultadoScreen> {
  String? _estado;
  bool _fallo = false;
  int _intentos = 0;
  Timer? _reloj;

  @override
  void initState() {
    super.initState();
    _consultar();
  }

  @override
  void dispose() {
    _reloj?.cancel();
    super.dispose();
  }

  Future<void> _consultar() async {
    _reloj?.cancel();
    setState(() => _fallo = false);
    try {
      final estado = await ref
          .read(pagosRepositoryProvider)
          .comprobarPago(widget.pagoId);
      if (!mounted) return;
      setState(() => _estado = estado);
      if (estado == 'pagado') {
        // Que Tarifas e Inicio vuelvan a pedir la cuota y el saldo.
        ref.invalidate(currentProfileProvider);
        return;
      }
      if (estado == 'creado' && ++_intentos < widget.intentosMaximos) {
        _reloj = Timer(widget.intervalo, _consultar);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _fallo = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final estado = _estado;
    final (icono, color, titulo, texto) = switch (estado) {
      'pagado' => (
        Icons.check_circle_outline,
        context.paleta.successFg,
        'Pago recibido',
        'Tu cuota ya está activa. Ya puedes reservar clase.',
      ),
      'revisar' => (
        Icons.report_problem_outlined,
        context.paleta.warningFg,
        'Hay que revisar tu pago',
        'Hemos recibido tu pago pero no hemos podido activar la cuota. '
            'Avisa a tu academia: ya tiene el aviso y lo resolverá.',
      ),
      'fallido' || 'expirado' => (
        Icons.cancel_outlined,
        context.paleta.dangerFg,
        'El pago no se ha completado',
        'No se te ha cobrado nada. Puedes volver a intentarlo desde Tarifas.',
      ),
      'reembolsado' => (
        Icons.undo_outlined,
        context.paleta.subtle,
        'Pago devuelto',
        'Este pago se ha devuelto.',
      ),
      _ when widget.cancelado => (
        Icons.cancel_outlined,
        context.paleta.subtle,
        'Has cancelado el pago',
        'No se te ha cobrado nada. Puedes volver a intentarlo desde Tarifas.',
      ),
      _ when _fallo => (
        Icons.wifi_off_outlined,
        context.paleta.warningFg,
        'No hemos podido comprobar tu pago',
        'Si has pagado, tu cuota se activará sola en unos minutos aunque cierres '
            'esta pantalla. Puedes volver a comprobarlo.',
      ),
      _ when estado == 'creado' && _intentos >= widget.intentosMaximos => (
        Icons.hourglass_top_outlined,
        context.paleta.warningFg,
        'Seguimos esperando la confirmación',
        'Si has pagado, tu cuota se activará sola en cuanto el banco lo '
            'confirme, aunque cierres esta pantalla.',
      ),
      _ => (
        Icons.hourglass_top_outlined,
        context.paleta.subtle,
        'Comprobando tu pago…',
        'Un momento. Puedes cerrar esta pantalla: la cuota se activa sola '
            'cuando se confirma el pago.',
      ),
    };

    final enEspera = estado == null && !_fallo && !widget.cancelado;
    final puedeReintentar =
        _fallo || (estado == 'creado' && _intentos >= widget.intentosMaximos);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (enEspera || (estado == 'creado' && !puedeReintentar))
              const SizedBox(
                height: 56,
                width: 56,
                child: CircularProgressIndicator(),
              )
            else
              Icon(icono, size: 56, color: color),
            const SizedBox(height: 20),
            Text(
              titulo,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              texto,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: context.paleta.subtle),
            ),
            const SizedBox(height: 24),
            if (puedeReintentar) ...[
              OutlinedButton(
                onPressed: () {
                  _intentos = 0;
                  _consultar();
                },
                child: const Text('Comprobar de nuevo'),
              ),
              const SizedBox(height: 12),
            ],
            FilledButton(
              onPressed: () => context.go(
                estado == 'pagado' ? Routes.inicio : Routes.perfil,
              ),
              child: Text(
                estado == 'pagado' ? 'Ir al inicio' : 'Volver a mi perfil',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
