/// Centralized route path constants so screens/redirects never hardcode strings.
class Routes {
  Routes._();

  static const String login = '/login';
  static const String olvideContrasena = '/olvide-contrasena';
  static const String restablecerContrasena = '/restablecer-contrasena';
  static const String privacidad = '/privacidad';
  static const String registro = '/registro';
  static const String registroAcademia = '/registro/academia';
  static const String splash = '/splash';
  static const String pendienteAprobacion = '/pendiente-aprobacion';
  static const String admin = '/admin';
  static const String solicitudesCambioEscuela = '/solicitudes-cambio-escuela';
  static const String cobros = '/cobros';
  static const String ajustesReservas = '/ajustes-reservas';
  static const String equipo = '/equipo';

  static const String inicio = '/inicio';
  static const String estadisticas = '/estadisticas';
  static const String novedades = '/novedades';
  static const String tienda = '/tienda';
  static const String tarifas = '/tarifas';
  static const String perfil = '/perfil';

  static const Set<String> publicRoutes = {
    login,
    olvideContrasena,
    restablecerContrasena,
    privacidad,
    registro,
    registroAcademia,
  };
}
