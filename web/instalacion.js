// Instalación como app (PWA). Va en un fichero aparte y no incrustado en la
// página porque la política de seguridad (script-src 'self') bloquea los
// scripts en línea. Lo usa lib/core/web/instalacion_web.dart.
(function () {
  var aviso = null;

  window.addEventListener('beforeinstallprompt', function (e) {
    // Guardamos el aviso para lanzarlo desde nuestro botón, no a destiempo.
    e.preventDefault();
    aviso = e;
  });

  window.addEventListener('appinstalled', function () {
    aviso = null;
  });

  function instalada() {
    return (
      (window.matchMedia && window.matchMedia('(display-mode: standalone)').matches) ||
      window.navigator.standalone === true
    );
  }

  function esIos() {
    var ua = window.navigator.userAgent || '';
    var ipadOs = navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1;
    return /iPhone|iPad|iPod/.test(ua) || ipadOs;
  }

  window.itacaInstalar = {
    instalada: instalada,
    esIos: esIos,
    disponible: function () {
      return aviso !== null;
    },
    // Devuelve 'aceptada', 'rechazada' o 'no_disponible'.
    instalar: function () {
      if (!aviso) return Promise.resolve('no_disponible');
      var a = aviso;
      aviso = null;
      a.prompt();
      return a.userChoice.then(function (r) {
        return r.outcome === 'accepted' ? 'aceptada' : 'rechazada';
      });
    },
  };
})();
