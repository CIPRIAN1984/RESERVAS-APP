import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import '../../app/theme/color_tokens.dart';
import '../../core/auth/auth_state.dart';

/// Shell for the authenticated app. Uses a Drawer rather than a bottom
/// NavigationBar because Material's bottom nav guidance tops out around 5
/// destinations — this app has 7 modules plus a conditional Admin entry,
/// which a Drawer accommodates without overflow menus.
class MainShell extends ConsumerWidget {
  const MainShell({required this.child, super.key});

  final Widget child;

  // Modules scoped to academia membership — not shown to Administrador, who
  // isn't a member of any single academia (its job is managing the platform).
  static const _itemsAcademia = <_NavItem>[
    _NavItem(Routes.inicio, 'Inicio', Icons.calendar_month_outlined, Icons.calendar_month),
    _NavItem(Routes.estadisticas, 'Estadísticas', Icons.leaderboard_outlined, Icons.leaderboard),
    _NavItem(Routes.novedades, 'Novedades', Icons.campaign_outlined, Icons.campaign),
    _NavItem(Routes.progreso, 'Árbol de Progreso', Icons.account_tree_outlined, Icons.account_tree),
    _NavItem(Routes.tienda, 'Tienda y Material', Icons.storefront_outlined, Icons.storefront),
    _NavItem(Routes.tarifas, 'Tarifas', Icons.card_membership_outlined, Icons.card_membership),
  ];

  static const _perfilItem =
      _NavItem(Routes.perfil, 'Perfil', Icons.person_outline, Icons.person);

  static const _adminItem =
      _NavItem(Routes.admin, 'Gestión de academias', Icons.verified_user_outlined, Icons.verified_user);

  static const _cambioEscuelaItem = _NavItem(
    Routes.solicitudesCambioEscuela,
    'Cambios de escuela',
    Icons.swap_horiz_outlined,
    Icons.swap_horiz,
  );

  static const _cobrosItem =
      _NavItem(Routes.cobros, 'Cobros', Icons.credit_card_outlined, Icons.credit_card);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider).value;
    final isAdmin = profile?.isAdministrador ?? false;
    final isDueno = profile?.isDueno ?? false;
    final location = GoRouterState.of(context).matchedLocation;

    final items = [
      if (!isAdmin) ..._itemsAcademia,
      if (isDueno) _cobrosItem,
      if (isDueno || isAdmin) _cambioEscuelaItem,
      if (isAdmin) _adminItem,
      _perfilItem,
    ];
    final current = items.firstWhere(
      (i) => i.route == location,
      orElse: () => items.first,
    );

    return Scaffold(
      appBar: AppBar(title: Text(current.label)),
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                child: Row(
                  children: [
                    Text(
                      'ITACA',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: 2),
                    ),
                    const Spacer(),
                    if (profile != null)
                      Chip(
                        label: Text(profile.rol),
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.divider),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    for (final item in items)
                      ListTile(
                        leading: Icon(item.route == location ? item.selectedIcon : item.icon),
                        title: Text(item.label),
                        selected: item.route == location,
                        selectedTileColor: AppColors.accentPrimary.withValues(alpha: 0.12),
                        onTap: () {
                          Navigator.of(context).pop();
                          if (item.route != location) context.go(item.route);
                        },
                      ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.divider),
              ListTile(
                leading: const Icon(Icons.logout, color: AppColors.danger),
                title: const Text('Cerrar sesión', style: TextStyle(color: AppColors.danger)),
                onTap: () {
                  Navigator.of(context).pop();
                  ref.read(authRepositoryProvider).signOut();
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
      body: SafeArea(child: child),
    );
  }
}

class _NavItem {
  const _NavItem(this.route, this.label, this.icon, this.selectedIcon);

  final String route;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}
