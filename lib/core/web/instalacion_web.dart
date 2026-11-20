import 'dart:js_interop';

import 'instalacion.dart';

/// Lo que expone `web/instalacion.js`.
extension type _Api(JSObject _) implements JSObject {
  external bool instalada();
  external bool esIos();
  external bool disponible();
  external JSPromise<JSString> instalar();
}

@JS('itacaInstalar')
external _Api? get _api;

InstalacionApp crearInstalacion() => _InstalacionWeb();

class _InstalacionWeb implements InstalacionApp {
  @override
  EstadoInstalacion estado() {
    final api = _api;
    if (api == null) return EstadoInstalacion.noDisponible;
    try {
      return decidirEstado(
        instalada: api.instalada(),
        botonDisponible: api.disponible(),
        esIos: api.esIos(),
      );
    } catch (_) {
      return EstadoInstalacion.noDisponible;
    }
  }

  @override
  Future<bool> instalar() async {
    final api = _api;
    if (api == null) return false;
    try {
      final resultado = (await api.instalar().toDart).toDart;
      return resultado == 'aceptada';
    } catch (_) {
      return false;
    }
  }
}
