import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/color_tokens.dart';
import '../../../core/auth/auth_state.dart';

class PendienteAprobacionScreen extends ConsumerWidget {
  const PendienteAprobacionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.hourglass_top_outlined,
                  size: 56,
                  color: AppColors.warningFg,
                ),
                const SizedBox(height: 24),
                Text(
                  'Tu academia está pendiente de aprobación',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                Text(
                  'El administrador de la plataforma tiene que revisar y aprobar tu academia '
                  'antes de que puedas acceder a ITACA. Te avisaremos en cuanto esté lista.',
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: AppColors.subtle),
                ),
                const SizedBox(height: 32),
                OutlinedButton.icon(
                  onPressed: () => ref.invalidate(currentProfileProvider),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Comprobar de nuevo'),
                ),
                const SizedBox(height: 12),
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
