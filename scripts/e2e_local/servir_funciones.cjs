// Sirve en local las funciones de Stripe con `deno` (mismo código que se
// despliega) y un encaminador en /functions/v1/<nombre>. Se usa porque el
// contenedor de funciones de `supabase start` no siempre puede bajar paquetes
// (proxies con certificado propio). Variables: SUPABASE_URL, ANON, SERVICE_ROLE,
// y las de Stripe de prueba (ver stripe_local.cjs).
const http = require("http");
const { spawn } = require("child_process");

const FUNCIONES = ["stripe-checkout-tarifa", "stripe-comprobar-pago", "stripe-webhook", "stripe-create-tarifa-subscription", "stripe-create-tienda-payment"];
const PUERTO = Number(process.env.PUERTO_FUNCIONES || 54399);
const puertos = {};
FUNCIONES.forEach((f, i) => {
  puertos[f] = 8101 + i;
  const hijo = spawn("deno", ["run", "-A", `supabase/functions/${f}/index.ts`], {
    env: {
      ...process.env,
      DENO_SERVE_ADDRESS: `tcp:127.0.0.1:${puertos[f]}`,
      SUPABASE_URL: process.env.SUPABASE_URL,
      SUPABASE_ANON_KEY: process.env.ANON,
      SUPABASE_SERVICE_ROLE_KEY: process.env.SERVICE_ROLE,
    },
    stdio: ["ignore", "inherit", "inherit"],
  });
  hijo.on("exit", (c) => console.log(`[${f}] terminó (${c})`));
});

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-client-info, x-supabase-api-version",
  "Access-Control-Allow-Methods": "GET, POST, PUT, PATCH, DELETE, OPTIONS",
};

// Un solo punto de entrada local: /functions/v1/<nombre> va a las funciones
// servidas con deno y todo lo demás (auth, base de datos, ficheros) pasa a
// Supabase, para poder apuntar la web de prueba aquí.
http
  .createServer((req, res) => {
    const m = req.url.match(/^\/functions\/v1\/([\w-]+)/);
    if (m) {
      if (req.method === "OPTIONS") {
        res.writeHead(204, CORS).end();
        return;
      }
      const puerto = puertos[m[1]];
      if (!puerto) {
        res.writeHead(404, CORS).end("no existe");
        return;
      }
      const salida = http.request(
        { host: "127.0.0.1", port: puerto, path: "/", method: req.method, headers: req.headers },
        (r) => {
          res.writeHead(r.statusCode, { ...r.headers, ...CORS });
          r.pipe(res);
        },
      );
      salida.on("error", () => res.writeHead(503, CORS).end("función no disponible"));
      req.pipe(salida);
      return;
    }
    const resto = http.request(
      { host: "127.0.0.1", port: 54321, path: req.url, method: req.method, headers: req.headers },
      (r) => {
        res.writeHead(r.statusCode, r.headers);
        r.pipe(res);
      },
    );
    resto.on("error", () => res.writeHead(502).end("Supabase no responde"));
    req.pipe(resto);
  })
  .listen(PUERTO, "127.0.0.1", () => console.log(`Local en http://127.0.0.1:${PUERTO} (funciones y Supabase)`));
