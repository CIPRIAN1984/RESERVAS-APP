import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/auth/auth_state.dart';
import '../core/models/profile.dart';
import '../features/admin/presentation/admin_academias_screen.dart';
import '../features/calendario/presentation/calendario_screen.dart';
import '../features/configuracion_reservas/presentation/ajustes_reservas_screen.dart';
import '../features/estadisticas/presentation/estadisticas_screen.dart';
import '../features/equipo/presentation/equipo_screen.dart';
import '../features/novedades/presentation/novedades_screen.dart';
import '../features/onboarding/presentation/login_screen.dart';
import '../features/pagos/presentation/conectar_stripe_screen.dart';
import '../features/progreso/presentation/arbol_progreso_screen.dart';
import '../features/tarifas/presentation/tarifas_screen.dart';
import '../features/tienda/presentation/tienda_screen.dart';
import '../features/onboarding/presentation/pendiente_aprobacion_screen.dart';
import '../features/onboarding/presentation/registro_academia_screen.dart';
import '../features/onboarding/presentation/registro_screen.dart';
import '../features/onboarding/presentation/splash_screen.dart';
import '../features/perfil/presentation/perfil_screen.dart';
import '../features/perfil/presentation/solicitudes_cambio_escuela_screen.dart';
import '../shared/navigation/main_shell.dart';
import 'routes.dart';

/// Notifies go_router to re-run [_redirect] whenever auth/profile state changes.
class _GoRouterRefreshNotifier extends ChangeNotifier {
  _GoRouterRefreshNotifier(Ref ref) {
    _authSub = ref.listen(
      authStateChangesProvider,
      (_, _) => notifyListeners(),
    );
    _profileSub = ref.listen(
      currentProfileProvider,
      (_, _) => notifyListeners(),
    );
  }

  late final ProviderSubscription<void> _authSub;
  late final ProviderSubscription<void> _profileSub;

  @override
  void dispose() {
    _authSub.close();
    _profileSub.close();
    super.dispose();
  }
}

/// Routes scoped to academia membership — Administrador isn't a member of
/// any single academia, so these don't apply to that role.
const _rutasAcademia = {
  Routes.inicio,
  Routes.estadisticas,
  Routes.novedades,
  Routes.progreso,
  Routes.tienda,
  Routes.tarifas,
  Routes.ajustesReservas,
};

String _inicioPara(Profile profile) =>
    profile.isAdministrador ? Routes.admin : Routes.inicio;

String? _redirect(Ref ref, GoRouterState state) {
  final loc = state.matchedLocation;
  final userId = ref.read(currentUserIdProvider);

  if (userId == null) {
    return Routes.publicRoutes.contains(loc) ? null : Routes.login;
  }

  final profileAsync = ref.read(currentProfileProvider);
  if (!profileAsync.hasValue) {
    return loc == Routes.splash ? null : Routes.splash;
  }

  final profile = profileAsync.value;

  if (profile == null) {
    // Signed up but hasn't finished picking/registering an academia yet.
    const registrationRoutes = {Routes.registro, Routes.registroAcademia};
    return registrationRoutes.contains(loc) ? null : Routes.registro;
  }

  if (profile.pendienteAprobacion && !profile.isAdministrador) {
    return loc == Routes.pendienteAprobacion
        ? null
        : Routes.pendienteAprobacion;
  }

  if (loc == Routes.admin && !profile.isAdministrador) {
    return _inicioPara(profile);
  }

  if (loc == Routes.solicitudesCambioEscuela &&
      !(profile.isDueno || profile.isAdministrador)) {
    return _inicioPara(profile);
  }

  if (loc == Routes.cobros && !profile.isDueno) {
    return _inicioPara(profile);
  }

  if (loc == Routes.ajustesReservas && !profile.isDueno) {
    return _inicioPara(profile);
  }

  if (loc == Routes.equipo && !profile.isDueno) {
    return _inicioPara(profile);
  }

  // Administrador isn't scoped to any single academia, so the member-facing
  // modules (calendario, tienda, etc.) don't apply to it.
  if (_rutasAcademia.contains(loc) && profile.isAdministrador) {
    return _inicioPara(profile);
  }

  final atEntryPoint =
      Routes.publicRoutes.contains(loc) ||
      loc == Routes.splash ||
      loc == Routes.pendienteAprobacion;
  if (atEntryPoint) {
    return _inicioPara(profile);
  }

  return null;
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _GoRouterRefreshNotifier(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: Routes.login,
    refreshListenable: refresh,
    redirect: (context, state) => _redirect(ref, state),
    routes: [
      GoRoute(
        path: Routes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: Routes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: Routes.registro,
        builder: (context, state) => const RegistroScreen(),
      ),
      GoRoute(
        path: Routes.registroAcademia,
        builder: (context, state) => const RegistroAcademiaScreen(),
      ),
      GoRoute(
        path: Routes.pendienteAprobacion,
        builder: (context, state) => const PendienteAprobacionScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: Routes.inicio,
            builder: (context, state) => const CalendarioScreen(),
          ),
          GoRoute(
            path: Routes.estadisticas,
            builder: (context, state) => const EstadisticasScreen(),
          ),
          GoRoute(
            path: Routes.novedades,
            builder: (context, state) => const NovedadesScreen(),
          ),
          GoRoute(
            path: Routes.progreso,
            builder: (context, state) => const ArbolProgresoScreen(),
          ),
          GoRoute(
            path: Routes.tienda,
            builder: (context, state) => const TiendaScreen(),
          ),
          GoRoute(
            path: Routes.tarifas,
            builder: (context, state) => const TarifasScreen(),
          ),
          GoRoute(
            path: Routes.perfil,
            builder: (context, state) => const PerfilScreen(),
          ),
          GoRoute(
            path: Routes.admin,
            builder: (context, state) => const AdminAcademiasScreen(),
          ),
          GoRoute(
            path: Routes.solicitudesCambioEscuela,
            builder: (context, state) => const SolicitudesCambioEscuelaScreen(),
          ),
          GoRoute(
            path: Routes.cobros,
            builder: (context, state) => const ConectarStripeScreen(),
          ),
          GoRoute(
            path: Routes.ajustesReservas,
            builder: (context, state) => const AjustesReservasScreen(),
          ),
          GoRoute(
            path: Routes.equipo,
            builder: (context, state) => const EquipoScreen(),
          ),
        ],
      ),
    ],
  );
});
