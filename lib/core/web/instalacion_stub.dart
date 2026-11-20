import 'instalacion.dart';

/// Fuera de la web (móvil nativo, pruebas): no hay nada que instalar.
InstalacionApp crearInstalacion() => _SinInstalacion();

class _SinInstalacion implements InstalacionApp {
  @override
  EstadoInstalacion estado() => EstadoInstalacion.noDisponible;

  @override
  Future<bool> instalar() async => false;
}
