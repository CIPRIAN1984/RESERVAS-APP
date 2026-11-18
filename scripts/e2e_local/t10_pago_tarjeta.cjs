// Recorrido en el navegador del pago con tarjeta. La página de pago real de
// Stripe no se abre aquí (stripe-mock devuelve una dirección ficticia): se
// intercepta la navegación y se simula lo que Stripe haría después con un
// aviso firmado. Lo que SÍ se ve de verdad: el botón, la llamada al servidor,
// la pantalla de vuelta y la cuota activada.
const L = require("./lib.cjs");
const crypto = require("crypto");
const { execFileSync } = require("child_process");
const sql = (q) => execFileSync("psql", [process.env.DB_URL, "-At", "-c", q], { encoding: "utf8" }).trim();

async function avisoStripe(tipo, objeto) {
  const cuerpo = JSON.stringify({ id: "evt_nav_" + Date.now(), object: "event", api_version: "2025-02-24.acacia", created: Math.floor(Date.now() / 1000), type: tipo, data: { object: objeto } });
  const t = Math.floor(Date.now() / 1000);
  const v1 = crypto.createHmac("sha256", process.env.WEBHOOK_SECRET).update(`${t}.${cuerpo}`).digest("hex");
  const r = await fetch("http://127.0.0.1:54399/functions/v1/stripe-webhook", { method: "POST", headers: { "Content-Type": "application/json", "Stripe-Signature": `t=${t},v1=${v1}` }, body: cuerpo });
  return r.status;
}

(async () => {
  const b = await L.abrir();
  const p = await L.sesion(b);
  const stripeVisitado = [];
  await p.route(/checkout\.stripe\.com|\.stripe\.com\/c\/pay/, (ruta) => { stripeVisitado.push(ruta.request().url()); ruta.abort(); });
  try {
    sql("delete from public.pagos_stripe; delete from public.suscripciones where alumno_id=(select id from auth.users where email='alumno2@prueba.itaca.test')");
    await L.entrar(p, "alumno2@prueba.itaca.test", process.env.CLAVE);
    await L.espera(p, "Reservar plaza", 20000);
    await L.hash(p, "#/tarifas");
    await L.espera(p, "Pagar con tarjeta", 15000);
    await L.foto(p, "30_tarifas_pagar");
    console.log("tarifas:", (await L.textos(p)).filter((t) => /€|Pagar|Bono|suelto|2 días|Ilimitada/i.test(t)).slice(0, 10).join(" | "));
    // El bono es la 2ª tarifa por precio ascendente; se pulsa por texto de su tarjeta.
    await L.pulsar(p, "Pagar con tarjeta", { n: 2 });
    await p.waitForTimeout(2500);
    const pago = sql("select id||'|'||estado||'|'||importe_esperado from public.pagos_stripe order by created_at desc limit 1");
    console.log("pago creado:", pago, "| intentó abrir Stripe:", stripeVisitado.length > 0);
    const [pagoId] = pago.split("|");
    await L.foto(p, "31_tras_pulsar");

    // Stripe confirma el cobro (aviso firmado) MIENTRAS la persona está en la página de pago.
    const ses = "cs_nav_" + pagoId.slice(0, 8);
    sql(`update public.pagos_stripe set checkout_session_id='${ses}' where id='${pagoId}'`);
    const imp = Math.round(Number(pago.split("|")[2]) * 100);
    console.log("webhook:", await avisoStripe("checkout.session.completed", { id: ses, object: "checkout.session", mode: "payment", payment_status: "paid", payment_intent: "pi_nav", amount_total: imp, currency: "eur", metadata: { pago_id: pagoId } }));
    console.log("cuota:", sql("select tarifa_nombre||'/'||estado||'/'||proveedor_pago from public.suscripciones s join auth.users u on u.id=s.alumno_id where u.email='alumno2@prueba.itaca.test'"));

    // La persona vuelve a la app desde la página de pago.
    await L.ir(p, `/#/pago?pago=${pagoId}`);
    await L.foto(p, "32_vuelta");
    console.log("pantalla de vuelta:", (await L.textos(p)).slice(0, 8).join(" | "));
  } catch (e) { console.log("ERROR", e.message.slice(0, 600)); await L.foto(p, "30_error"); }
  console.log("errores:", p.errores.slice(0, 3));
  await b.close();
})();
