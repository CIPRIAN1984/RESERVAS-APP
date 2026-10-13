import 'package:flutter/material.dart';

import '../../app/theme/color_tokens.dart';

/// Un dato que no ha cargado, dicho en su sitio y con «Reintentar».
///
/// Auditoría del 09/10/2026: el saldo de clases, la cuota de un hijo o sus
/// documentos desaparecían sin más si fallaba la conexión. Un hueco se lee
/// como «no tengo nada», que es justo lo que no es.
class ErrorEnLinea extends StatelessWidget {
  const ErrorEnLinea({
    required this.mensaje,
    required this.onReintentar,
    super.key,
  });

  final String mensaje;
  final VoidCallback onReintentar;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          mensaje,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.destructive),
        ),
        TextButton.icon(
          onPressed: onReintentar,
          icon: const Icon(Icons.refresh, size: 18),
          label: const Text('Reintentar'),
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: const Size(44, 44),
          ),
        ),
      ],
    );
  }
}
