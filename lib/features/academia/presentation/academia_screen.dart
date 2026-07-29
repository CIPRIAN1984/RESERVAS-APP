import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../app/theme/color_tokens.dart';
import '../../../core/auth/auth_state.dart';
import '../../../shared/widgets/pantalla.dart';

/// Centro de gestión de la academia: identidad, equipo y los ajustes que
/// solo toca quien la lleva. Reúne en un sitio lo que antes estaba suelto
/// por el menú lateral.
class AcademiaScreen extends ConsumerWidget {
  const AcademiaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final academia = ref.watch(currentAcademiaProvider).value;
    final profile = ref.watch(currentProfileProvider).value;
    final esDueno = profile?.isDueno ?? false;

    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        const TituloPantalla('Academia'),

        // Identidad de la academia.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.line),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: const BoxDecoration(
                    color: AppColors.ink,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'I+',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        academia?.nombre ?? 'Tu academia',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      if (academia?.direccion != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.place_outlined,
                              size: 15,
                              color: AppColors.subtle,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                academia!.direccion!,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 24),

        // Accesos grandes a lo que más se usa.
        if (esDueno)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: _Bloque(
                    icono: Icons.groups_outlined,
                    titulo: 'Equipo',
                    onTap: () => context.go(Routes.equipo),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _Bloque(
                    icono: Icons.credit_card_outlined,
                    titulo: 'Cobros',
                    onTap: () => context.go(Routes.cobros),
                  ),
                ),
              ],
            ),
          ),

        const SizedBox(height: 28),

        _Seccion('Configuración'),
        if (esDueno)
          _Fila(
            icono: Icons.tune_outlined,
            texto: 'Ajustes de reservas',
            onTap: () => context.go(Routes.ajustesReservas),
          ),
        if (esDueno)
          _Fila(
            icono: Icons.swap_horiz_outlined,
            texto: 'Cambios de escuela',
            onTap: () => context.go(Routes.solicitudesCambioEscuela),
          ),
        _Fila(
          icono: Icons.privacy_tip_outlined,
          texto: 'Privacidad y protección de datos',
          onTap: () => context.go(Routes.privacidad),
        ),

        const SizedBox(height: 20),
        const Divider(indent: 20, endIndent: 20),
        const SizedBox(height: 4),

        _Fila(
          icono: Icons.logout,
          texto: 'Cerrar sesión',
          destructiva: true,
          onTap: () => ref.read(authRepositoryProvider).signOut(),
        ),
      ],
    );
  }
}

class _Seccion extends StatelessWidget {
  const _Seccion(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      child: Text(texto, style: Theme.of(context).textTheme.titleLarge),
    );
  }
}

class _Bloque extends StatelessWidget {
  const _Bloque({
    required this.icono,
    required this.titulo,
    required this.onTap,
  });

  final IconData icono;
  final String titulo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 26),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            Icon(icono, size: 24),
            const SizedBox(height: 10),
            Text(titulo, style: Theme.of(context).textTheme.titleSmall),
          ],
        ),
      ),
    );
  }
}

class _Fila extends StatelessWidget {
  const _Fila({
    required this.icono,
    required this.texto,
    required this.onTap,
    this.destructiva = false,
  });

  final IconData icono;
  final String texto;
  final VoidCallback onTap;
  final bool destructiva;

  @override
  Widget build(BuildContext context) {
    final color = destructiva ? AppColors.destructive : AppColors.ink;
    return ListTile(
      onTap: onTap,
      leading: Icon(icono, color: color, size: 22),
      title: Text(texto, style: TextStyle(fontSize: 16, color: color)),
      trailing: destructiva
          ? null
          : const Icon(
              Icons.chevron_right,
              color: AppColors.disabled,
              size: 22,
            ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
    );
  }
}
