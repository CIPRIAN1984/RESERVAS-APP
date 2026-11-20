import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/color_tokens.dart';
import '../../../core/auth/auth_state.dart';

class PendienteAprobacionScreen extends ConsumerWidget {
  const PendienteAprobacionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // La misma pantalla para quien espera aprobación y para quien está de
    // baja: en los dos casos no hay acceso a nada de la academia (17/11/2026).
    final deBaja = ref.watch(currentProfileProvider).value?.deBaja ?? false;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  deBaja ? Icons.block_outlined : Icons.hourglass_top_outlined,
                  size: 56,
                  color: AppColors.warningFg,
                ),
                const SizedBox(height: 24),
                Text(
                  deBaja
                      ? 'Tu cuenta está de baja'
                      : 'Tu alta está pendiente de aprobación',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                Text(
                  deBaja
                      ? 'Ya no tienes acceso a la academia. Si quieres volver, '
                            'habla con tu academia para que te reactiven.'
                      : 'Tu academia tiene que aprobar tu alta antes de que '
                            'puedas entrar. Cuando lo haga, pulsa «Comprobar de '
                            'nuevo».',
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: AppColors.subtle),
                ),
                const SizedBox(height: 32),
                if (!deBaja) ...[
                  OutlinedButton.icon(
                    onPressed: () => ref.invalidate(currentProfileProvider),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Comprobar de nuevo'),
                  ),
                  const SizedBox(height: 12),
                ],
                TextButton(
                  onPressed: () => ref.read(authRepositoryProvider).signOut(),
                  child: const Text('Cerrar sesión'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
