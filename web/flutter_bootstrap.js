{{flutter_js}}
{{flutter_build_config}}

_flutter.loader.load({
  serviceWorkerSettings: {
    serviceWorkerVersion: {{flutter_service_worker_version}}
  },
  config: {
    // Sin esto, el motor gráfico CanvasKit se descarga desde
    // www.gstatic.com (Google) en cada arranque. En redes con DNS
    // filtrado ese dominio no resuelve y la app se queda cargando para
    // siempre sin ningún error visible. Igual que con las tipografías:
    // servimos CanvasKit desde el propio dominio (ya se incluye en el
    // build web bajo /canvaskit/, solo faltaba decirle al loader que lo
    // usara).
    canvasKitBaseUrl: "canvaskit/"
  }
});
