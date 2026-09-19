import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/color_tokens.dart';
import '../../../core/auth/auth_state.dart';
import '../../perfil/application/profile_providers.dart';
import 'documentos_seccion.dart';

/// Certificado médico y descargo de responsabilidad: los del propio usuario
/// y los de cada hijo a su cargo. Sin esto no hay forma de saber, antes de
/// que alguien se haga daño en el tatami, si tiene el papeleo en regla.
class MisDocumentosScreen extends ConsumerWidget {
  const MisDocumentosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(currentUserIdProvider);
    final hijosAsync = ref.watch(hijosProvider);

    if (userId == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Tus documentos', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        SeccionDocumentos(
          alumnoId: userId,
          subidoPorId: userId,
          puedeSubir: true,
          puedeBorrar: false,
        ),
        hijosAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (e, st) => const SizedBox.shrink(),
          data: (hijos) {
            if (hijos.isEmpty) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final hijo in hijos) ...[
                  const SizedBox(height: 24),
                  Text(
                    'Documentos de '
                    '${[hijo.nombre, hijo.apellidos].whereType<String>().join(' ')}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  SeccionDocumentos(
                    alumnoId: hijo.id,
                    subidoPorId: userId,
                    puedeSubir: true,
                    puedeBorrar: false,
                  ),
                ],
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        Text(
          'Solo lo ve el equipo de tu academia, para saber que está en '
          'regla antes de que suba al tatami.',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.subtle),
        ),
      ],
    );
  }
}
