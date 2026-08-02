import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../app/theme/app_theme.dart';
import '../../../app/theme/color_tokens.dart';
import '../../../core/auth/auth_state.dart';

/// El enlace lleva al registro (`RegistroScreen`) con la academia ya fijada
/// por parámetro de consulta, así quien lo abre no elige de la lista abierta
/// de academias de la plataforma.
String enlaceInvitacion(String academiaId) =>
    'https://itc2-reservas.vercel.app/#/registro?academia=$academiaId';

/// Solo el dueño: enlace y QR para invitar gente a unirse directamente a su
/// academia, sin pasar por el desplegable con todas las aprobadas.
class InvitarScreen extends ConsumerWidget {
  const InvitarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final academia = ref.watch(currentAcademiaProvider).value;
    if (academia == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final enlace = enlaceInvitacion(academia.id);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Comparte este QR o el enlace con quien quiera unirse a '
          '${academia.nombre}. Al entrar por aquí, la academia ya viene '
          'elegida: no verán la lista de todas las academias de la app.',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.subtle),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: QrImageView(
                data: enlace,
                size: 220,
                backgroundColor: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            enlace,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontFamily: AppTheme.fontMono,
              color: AppColors.ink,
            ),
          ),
        ),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: enlace));
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Enlace copiado.')),
              );
            }
          },
          icon: const Icon(Icons.copy_outlined),
          label: const Text('Copiar enlace'),
        ),
      ],
    );
  }
}
