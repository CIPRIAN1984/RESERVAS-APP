// Protección del service worker frente a respuestas equivocadas.
// Cloudflare Pages responde con index.html (código 200) a cualquier ruta que no
// existe. Si el service worker se instala mientras se publica una versión, podía
// guardar esa página en lugar de un .css o un .js, y la app se quedaba sin
// estilos para siempre (los archivos con hash no se vuelven a descargar).
// 1) Una página HTML recibida en lugar de un archivo se trata como error 404:
//    la instalación falla y se reintenta más tarde.
// 2) Al activarse, se borran las copias erróneas que ya estuvieran guardadas.
;(() => {
  const FILE = /\.(?:css|js|mjs|woff2?|png|svg|webmanifest|json)$/i
  const isHtml = (res) => (res.headers.get('content-type') || '').includes('text/html')
  const isOwnFile = (url) => url.origin === self.location.origin && FILE.test(url.pathname)

  const nativeFetch = self.fetch.bind(self)
  self.fetch = async (input, init) => {
    const res = await nativeFetch(input, init)
    const url = new URL(input instanceof Request ? input.url : String(input), self.location.href)
    if (isOwnFile(url) && isHtml(res)) return new Response('', { status: 404, statusText: 'Not Found' })
    return res
  }

  self.addEventListener('activate', (event) => {
    event.waitUntil(
      (async () => {
        for (const name of await caches.keys()) {
          const cache = await caches.open(name)
          for (const req of await cache.keys()) {
            if (!isOwnFile(new URL(req.url))) continue
            const res = await cache.match(req)
            if (res && isHtml(res)) await cache.delete(req)
          }
        }
      })(),
    )
  })
})()
