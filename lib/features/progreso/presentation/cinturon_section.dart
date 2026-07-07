import 'package:flutter/material.dart';

import '../../../app/theme/color_tokens.dart';
import '../data/tecnica.dart';

class CinturonSection extends StatelessWidget {
  const CinturonSection({
    required this.cinturon,
    required this.tecnicas,
    required this.onTapTecnica,
    this.progreso,
    super.key,
  });

  final String cinturon;
  final List<Tecnica> tecnicas;
  final Map<String, String>? progreso;
  final ValueChanged<Tecnica> onTapTecnica;

  static const _iconos = {
    'bloqueada': Icons.lock_outline,
    'en_proceso': Icons.hourglass_top,
    'conseguida': Icons.check_circle,
  };

  static const _colores = {
    'bloqueada': AppColors.tecnicaBloqueada,
    'en_proceso': AppColors.tecnicaEnProceso,
    'conseguida': AppColors.tecnicaConseguida,
  };

  @override
  Widget build(BuildContext context) {
    final colorCinturon = AppColors.beltColors[cinturon] ?? AppColors.textSecondary;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: true,
          leading: Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: colorCinturon,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.divider),
            ),
          ),
          title: Text('${nombreCinturones[cinturon] ?? cinturon} (${tecnicas.length})'),
          children: [
            for (final tecnica in tecnicas) _buildTecnicaTile(context, tecnica),
          ],
        ),
      ),
    );
  }

  Widget _buildTecnicaTile(BuildContext context, Tecnica tecnica) {
    final estado = progreso?[tecnica.id];
    return ListTile(
      title: Text(tecnica.nombre),
      subtitle: tecnica.descripcion != null ? Text(tecnica.descripcion!, maxLines: 1, overflow: TextOverflow.ellipsis) : null,
      leading: estado != null
          ? Icon(_iconos[estado] ?? Icons.circle, color: _colores[estado] ?? AppColors.textSecondary)
          : const Icon(Icons.chevron_right, color: AppColors.textSecondary),
      onTap: () => onTapTecnica(tecnica),
    );
  }
}
