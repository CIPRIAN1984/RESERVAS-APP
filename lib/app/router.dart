import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../core/auth/auth_state.dart';
import '../core/models/profile.dart';
import '../features/academia/presentation/academia_screen.dart';
import '../features/admin/presentation/admin_academias_screen.dart';
import '../features/herramientas/presentation/herramientas_screen.dart';
import '../features/calendario/presentation/calendario_screen.dart';
import '../features/configuracion_reservas/presentation/ajustes_reservas_screen.dart';
import '../features/estadisticas/presentation/estadisticas_screen.dart';
import '../features/equipo/presentation/equipo_screen.dart';
import '../features/novedades/presentation/novedades_screen.dart';
import '../features/onboarding/presentation/login_screen.dart';
import '../features/onboarding/presentation/olvide_contrasena_screen.dart';
import '../features/pagos/presentation/conectar_stripe_screen.dart';
import '../features/privacy/presentation/privacy_screen.dart';
import '../features/tarifas/presentation/tarifas_screen.dart';
import '../features/tienda/presentation/tienda_screen.dart';
import '../features/onboarding/presentation/pendiente_aprobacion_screen.dart';
import '../features/onboarding/presentation/registro_academia_screen.dart';
import '../features/onboarding/presentation/registro_screen.dart';
import '../features/onboarding/presentation/restablecer_contrasena_screen.dart';
import '../features/onboarding/presentation/splash_screen.dart';
import '../features/perfil/presentation/perfil_screen.dart';
import '../features/perfil/presentation/solicitudes_cambio_escuela_screen.dart';
import '../shared/navigation/main_shell.dart';
import '../shared/widgets/pantalla.dart';
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
  Routes.tienda,
  Routes.tarifas,
  Routes.ajustesReservas,
  Routes.herramientas,
  Routes.academia,
};

/// Destinos del modo Gestor: solo para quien lleva la academia.
const _rutasGestor = {Routes.herramientas, Routes.academia};

String _inicioPara(Profile profile) =>
    profile.isAdministrador ? Routes.admin : Routes.inicio;

String? _redirect(Ref ref, GoRouterState state) {
  final loc = state.matchedLocation;
  final userId = ref.read(currentUserIdProvider);
  final authEvent = ref.read(authStateChangesProvider).value?.event;

  if (userId == null) {
    return Routes.publicRoutes.contains(loc) ? null : Routes.login;
  }

  if (authEvent == sb.AuthChangeEvent.passwordRecovery &&
      loc != Routes.restablecerContrasena) {
    return Routes.restablecerContrasena;
  }

  if (loc == Routes.restablecerContrasena) return null;
  if (loc == Routes.privacidad) return null;

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

  // Un alumno no entra en el modo Gestor ni escribiendo la dirección a mano.
  if (_rutasGestor.contains(loc) && !(profile.isDueno || profile.isProfesor)) {
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
        path: Routes.olvideContrasena,
        builder: (context, state) => const OlvideContrasenaScreen(),
      ),
      GoRoute(
        path: Routes.restablecerContrasena,
        builder: (context, state) => const RestablecerContrasenaScreen(),
      ),
      GoRoute(
        path: Routes.privacidad,
        builder: (context, state) => const PrivacyScreen(),
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
            path: Routes.herramientas,
            builder: (context, state) => const HerramientasScreen(),
          ),
          GoRoute(
            path: Routes.academia,
            builder: (context, state) => const PantallaConTitulo(
              titulo: 'Academia',
              child: AcademiaScreen(),
            ),
          ),
          GoRoute(
            path: Routes.estadisticas,
            builder: (context, state) => const EstadisticasScreen(),
          ),
          GoRoute(
            path: Routes.novedades,
            builder: (context, state) => const PantallaConTitulo(
              titulo: 'Novedades',
              child: NovedadesScreen(),
            ),
          ),
          GoRoute(
            path: Routes.tienda,
            builder: (context, state) => PantallaConTitulo(
              titulo: 'Tienda y material',
              onVolver: () => context.go(Routes.academia),
              child: const TiendaScreen(),
            ),
          ),
          GoRoute(
            path: Routes.tarifas,
            builder: (context, state) => PantallaConTitulo(
              titulo: 'Tarifas y planes',
              onVolver: () => context.go(Routes.academia),
              child: const TarifasScreen(),
            ),
          ),
          GoRoute(
            path: Routes.perfil,
            builder: (context, state) => const PantallaConTitulo(
              titulo: 'Perfil',
              child: PerfilScreen(),
            ),
          ),
          GoRoute(
            path: Routes.admin,
            builder: (context, state) => const PantallaConTitulo(
              titulo: 'Academias',
              child: AdminAcademiasScreen(),
            ),
          ),
          GoRoute(
            path: Routes.solicitudesCambioEscuela,
            builder: (context, state) => PantallaConTitulo(
              titulo: 'Cambios de escuela',
              onVolver: () => context.go(Routes.academia),
              child: const SolicitudesCambioEscuelaScreen(),
            ),
          ),
          GoRoute(
            path: Routes.cobros,
            builder: (context, state) => PantallaConTitulo(
              titulo: 'Cobros',
              onVolver: () => context.go(Routes.academia),
              child: const ConectarStripeScreen(),
            ),
          ),
          GoRoute(
            path: Routes.ajustesReservas,
            builder: (context, state) => PantallaConTitulo(
              titulo: 'Ajustes de reservas',
              onVolver: () => context.go(Routes.academia),
              child: const AjustesReservasScreen(),
            ),
          ),
          GoRoute(
            path: Routes.equipo,
            builder: (context, state) => PantallaConTitulo(
              titulo: 'Equipo',
              onVolver: () => context.go(Routes.academia),
              child: const EquipoScreen(),
            ),
          ),
        ],
      ),
    ],
  );
});
