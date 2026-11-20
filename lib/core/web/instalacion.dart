import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'instalacion_stub.dart'
    if (dart.library.js_interop) 'instalacion_web.dart'
    as plataforma;

/// Qué se le puede ofrecer a la persona para tener la app en su pantalla de
/// inicio, sin pasar por las tiendas (PWA).
enum EstadoInstalacion {
  /// No es la web, o el navegador no permite instalar: no se muestra nada.
  noDisponible,

  /// Ya está instalada (abierta como app): no se muestra nada.
  yaInstalada,

  /// El navegador ofrece instalar con un botón (Android, Chrome, Edge).
  conBoton,

  /// iPhone/iPad: no hay botón; hay que seguir los pasos de Safari.
  pasosIos,
}

/// Puerta al navegador. Se sustituye en las pruebas.
abstract class InstalacionApp {
  EstadoInstalacion estado();

  /// Lanza la instalación. `true` si la persona aceptó.
  Future<bool> instalar();
}

final instalacionProvider = Provider<InstalacionApp>(
  (ref) => plataforma.crearInstalacion(),
);

/// Decide el estado a partir de lo que dice el navegador. Aparte para poder
/// probarlo sin navegador.
EstadoInstalacion decidirEstado({
  required bool instalada,
  required bool botonDisponible,
  required bool esIos,
}) {
  if (instalada) return EstadoInstalacion.yaInstalada;
  if (botonDisponible) return EstadoInstalacion.conBoton;
  if (esIos) return EstadoInstalacion.pasosIos;
  return EstadoInstalacion.noDisponible;
}
