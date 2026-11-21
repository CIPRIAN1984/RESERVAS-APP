// Prueba de integración del cobro con tarjeta, EN LOCAL, sin Stripe real.
//
// - La función `stripe-checkout-tarifa` habla con `stripe-mock` (servidor de
//   pruebas oficial de Stripe, que valida que las peticiones sean correctas).
// - Los avisos de Stripe al webhook se FIRMAN aquí con el secreto de prueba:
//   se ejercita la verificación de firma real, pero el contenido lo fabrico
//   yo. Por eso esto NO sustituye a la prueba con el entorno aislado de
//   Stripe: demuestra la lógica del servidor, no el pago de verdad.
//
// Uso: SUPABASE_URL=… ANON=… DB_URL=… CLAVE=… WEBHOOK_SECRET=… node stripe_local.cjs
const crypto = require("crypto");
const { execFileSync } = require("child_process");

const URL_API = process.env.SUPABASE_URL;
const FUNCIONES_URL = process.env.FUNCIONES_URL;
const ANON = process.env.ANON;
const DB = process.env.DB_URL;
const CLAVE = process.env.CLAVE;
const SECRETO = process.env.WEBHOOK_SECRET;
const TARIFA = {
  mensual: "33333333-3333-4333-8333-333333333302",
  bono: "33333333-3333-4333-8333-333333333303",
  suelta: "33333333-3333-4333-8333-333333333304",
};

let ok = 0;
let mal = 0;
function comprueba(nombre, cond, detalle = "") {
  if (cond) ok++;
  else mal++;
  console.log(`${cond ? "✅" : "❌"} ${nombre}${cond ? "" : "  → " + detalle}`);
}

function sql(consulta) {
  return execFileSync("psql", [DB, "-At", "-c", consulta], { encoding: "utf8" }).trim();
}

async function entrar(correo) {
  const r = await fetch(`${URL_API}/auth/v1/token?grant_type=password`, {
    method: "POST",
    headers: { apikey: ANON, "Content-Type": "application/json" },
    body: JSON.stringify({ email: correo, password: CLAVE }),
  });
  const j = await r.json();
  if (!j.access_token) throw new Error("No entra " + correo + ": " + JSON.stringify(j));
  return j.access_token;
}

async function pagar(token, cuerpo) {
  const r = await fetch(`${FUNCIONES_URL || URL_API + "/functions/v1"}/stripe-checkout-tarifa`, {
    method: "POST",
    headers: { apikey: ANON, Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
    body: JSON.stringify(cuerpo),
  });
  return { estado: r.status, cuerpo: await r.json().catch(() => ({})) };
}

async function webhook(evento, { firmar = true, secreto = SECRETO } = {}) {
  const carga = JSON.stringify(evento);
  const t = Math.floor(Date.now() / 1000);
  const v1 = crypto.createHmac("sha256", secreto).update(`${t}.${carga}`).digest("hex");
  const cabeceras = { "Content-Type": "application/json" };
  if (firmar) cabeceras["Stripe-Signature"] = `t=${t},v1=${v1}`;
  const r = await fetch(`${FUNCIONES_URL || URL_API + "/functions/v1"}/stripe-webhook`, {
    method: "POST",
    headers: cabeceras,
    body: carga,
  });
  return { estado: r.status, texto: await r.text() };
}

let n = 0;
const evento = (tipo, objeto) => ({
  id: `evt_local_${Date.now()}_${n++}`,
  object: "event",
  api_version: "2025-02-24.acacia",
  created: Math.floor(Date.now() / 1000),
  type: tipo,
  data: { object: objeto },
});
const sesionPagada = (id, pagoId, centimos, pi, extra = {}) => ({
  id,
  object: "checkout.session",
  mode: "payment",
  payment_status: "paid",
  status: "complete",
  payment_intent: pi,
  amount_total: centimos,
  currency: "eur",
  metadata: { pago_id: pagoId },
  ...extra,
});

// Primer cobro de una tarifa MENSUAL: Checkout en modo suscripción.
const sesionSuscripcion = (id, pagoId, centimos, subId, extra = {}) => ({
  id,
  object: "checkout.session",
  mode: "subscription",
  payment_status: "paid",
  status: "complete",
  subscription: subId,
  amount_total: centimos,
  currency: "eur",
  metadata: { pago_id: pagoId },
  ...extra,
});

// stripe-mock devuelve siempre el mismo id de sesión; para poder abrir varios
// pagos se renombra el anterior (un id único por pago, como hace Stripe).
function renombrarSesiones() {
  sql(`update public.pagos_stripe set checkout_session_id = 'cs_local_' || substr(id::text,1,8) where checkout_session_id !~ '^cs_local_'`);
}

(async () => {
  console.log("── Antes de pagar ──");
  const tAlumno1 = await entrar("alumno1@prueba.itaca.test");
  const tAlumno2 = await entrar("alumno2@prueba.itaca.test");
  const tTutor = await entrar("tutor@prueba.itaca.test");
  const idAlumno1 = sql("select id from auth.users where email='alumno1@prueba.itaca.test'");
  const hijo = "22222222-2222-4222-8222-222222222222";

  const sinFirma = await webhook(evento("checkout.session.completed", {}), { firmar: false });
  comprueba("El webhook rechaza un aviso sin firma de Stripe (400)", sinFirma.estado === 400, sinFirma.estado);
  const firmaFalsa = await webhook(evento("checkout.session.completed", {}), { secreto: "whsec_otro" });
  comprueba("Y uno con firma falsa (400)", firmaFalsa.estado === 400, firmaFalsa.estado);

  const sinSesion = await pagar("token_falso", { tarifa_id: TARIFA.bono });
  comprueba("Sin sesión válida no se puede iniciar un pago (401)", sinSesion.estado === 401, sinSesion.estado);

  console.log("── Pago correcto del bono trimestral ──");
  const p1 = await pagar(tAlumno1, { tarifa_id: TARIFA.bono });
  comprueba("Se crea la página de pago (200 con url)", p1.estado === 200 && !!p1.cuerpo.url, JSON.stringify(p1));
  const pagoId1 = p1.cuerpo.pago_id;
  comprueba(
    "El importe lo pone el servidor: 8000 céntimos",
    sql(`select round(importe_esperado*100) from public.pagos_stripe where id='${pagoId1}'`) === "8000",
  );
  comprueba(
    "Todavía NO hay cuota: crear el pago no activa nada",
    sql(`select count(*) from public.suscripciones where alumno_id='${idAlumno1}'`) === "0",
  );
  const otraVez = await pagar(tAlumno1, { tarifa_id: TARIFA.bono });
  comprueba("Pulsar otra vez reutiliza el mismo pago", otraVez.cuerpo.pago_id === pagoId1, JSON.stringify(otraVez));
  renombrarSesiones();
  const ses1 = sql(`select checkout_session_id from public.pagos_stripe where id='${pagoId1}'`);

  const cobro = evento("checkout.session.completed", sesionPagada(ses1, pagoId1, 8000, "pi_local_1"));
  const w1 = await webhook(cobro);
  comprueba("Stripe confirma el pago: el webhook responde 200", w1.estado === 200, w1.texto);
  comprueba(
    "La cuota queda activa: bono, 10 clases, trimestral, 80 €, tarjeta",
    sql(`select tarifa_nombre||'/'||clases_incluidas||'/'||periodicidad||'/'||estado||'/'||proveedor_pago||'/'||importe_cobrado from public.suscripciones where alumno_id='${idAlumno1}'`) ===
      "Bono 10 sesiones/10/trimestral/activa/stripe/80.00",
  );

  console.log("── Aviso duplicado ──");
  const w1b = await webhook(cobro);
  comprueba("El mismo aviso otra vez: 200, sin error", w1b.estado === 200, w1b.texto);
  const w1c = await webhook(evento("checkout.session.completed", sesionPagada(ses1, pagoId1, 8000, "pi_local_1")));
  comprueba("Un aviso distinto del mismo pago tampoco duplica", w1c.estado === 200, w1c.texto);
  comprueba(
    "Sigue habiendo UNA sola cuota",
    sql(`select count(*) from public.suscripciones where alumno_id='${idAlumno1}'`) === "1",
  );

  console.log("── Importe que no cuadra ──");
  const p2 = await pagar(tAlumno2, { tarifa_id: TARIFA.mensual });
  renombrarSesiones();
  const ses2 = sql(`select checkout_session_id from public.pagos_stripe where id='${p2.cuerpo.pago_id}'`);
  const w2 = await webhook(evento("checkout.session.completed", sesionSuscripcion(ses2, p2.cuerpo.pago_id, 100, "sub_local_2")));
  comprueba("Aviso con 1 € en una cuota de 50 €: 200 pero NO se activa", w2.estado === 200, w2.texto);
  comprueba(
    "Queda «revisar» y sin cuota",
    sql(`select estado from public.pagos_stripe where id='${p2.cuerpo.pago_id}'`) === "revisar" &&
      sql(`select count(*) from public.suscripciones s join auth.users u on u.id=s.alumno_id where u.email='alumno2@prueba.itaca.test'`) === "0",
  );

  console.log("── Fallo, reintento y abandono ──");
  const p3 = await pagar(tTutor, { tarifa_id: TARIFA.mensual, alumno_id: hijo });
  comprueba("Un tutor puede pagar la cuota de su hijo", p3.estado === 200, JSON.stringify(p3));
  renombrarSesiones();
  const ses3 = sql(`select checkout_session_id from public.pagos_stripe where id='${p3.cuerpo.pago_id}'`);
  await webhook(evento("payment_intent.payment_failed", {
    id: "pi_local_3", object: "payment_intent", metadata: { pago_id: p3.cuerpo.pago_id },
    last_payment_error: { message: "Tu tarjeta ha sido rechazada." },
  }));
  comprueba(
    "Un intento rechazado se anota y el pago sigue abierto",
    sql(`select estado||'/'||intentos_fallidos||'/'||error from public.pagos_stripe where id='${p3.cuerpo.pago_id}'`) ===
      "creado/1/Tu tarjeta ha sido rechazada.",
  );
  await webhook(evento("checkout.session.completed", sesionSuscripcion(ses3, p3.cuerpo.pago_id, 5000, "sub_local_3")));
  comprueba(
    "El reintento que sale bien activa la cuota del HIJO",
    sql(`select count(*) from public.suscripciones where alumno_id='${hijo}' and estado='activa'`) === "1",
  );

  const extranio = await pagar(tAlumno2, { tarifa_id: TARIFA.mensual, alumno_id: hijo });
  comprueba("Quien no es su tutor no puede pagar la cuota de ese niño (409)", extranio.estado === 409, JSON.stringify(extranio));

  const p4 = await pagar(tAlumno2, { tarifa_id: TARIFA.suelta });
  renombrarSesiones();
  const ses4 = sql(`select checkout_session_id from public.pagos_stripe where id='${p4.cuerpo.pago_id}'`);
  await webhook(evento("checkout.session.expired", { id: ses4, object: "checkout.session", mode: "payment", metadata: { pago_id: p4.cuerpo.pago_id } }));
  comprueba(
    "Un pago abandonado (la página caduca) queda «expirado», sin cuota",
    sql(`select estado from public.pagos_stripe where id='${p4.cuerpo.pago_id}'`) === "expirado",
  );

  console.log("── Pago pendiente (se cobra más tarde) ──");
  const p5 = await pagar(tAlumno2, { tarifa_id: TARIFA.suelta });
  renombrarSesiones();
  const ses5 = sql(`select checkout_session_id from public.pagos_stripe where id='${p5.cuerpo.pago_id}'`);
  await webhook(evento("checkout.session.completed", sesionPagada(ses5, p5.cuerpo.pago_id, 1000, null, { payment_status: "unpaid" })));
  comprueba(
    "«Completada» pero todavía sin cobrar: no se activa",
    sql(`select estado from public.pagos_stripe where id='${p5.cuerpo.pago_id}'`) === "creado",
  );
  await webhook(evento("checkout.session.async_payment_succeeded", sesionPagada(ses5, p5.cuerpo.pago_id, 1000, "pi_local_5")));
  comprueba(
    "Cuando Stripe confirma el cobro, se activa (día suelto: 1 clase)",
    sql(`select clases_incluidas||'/'||estado from public.suscripciones s join auth.users u on u.id=s.alumno_id where u.email='alumno2@prueba.itaca.test'`) === "1/activa",
  );

  console.log("── Devolución ──");
  await webhook(evento("charge.refunded", { id: "ch_local_1", object: "charge", payment_intent: "pi_local_1", amount_refunded: 2000 }));
  comprueba(
    "Una devolución parcial no cierra la cuota",
    sql(`select estado from public.suscripciones where alumno_id='${idAlumno1}'`) === "activa",
  );
  await webhook(evento("charge.refunded", { id: "ch_local_1", object: "charge", payment_intent: "pi_local_1", amount_refunded: 8000 }));
  comprueba(
    "Una devolución total cancela la cuota",
    sql(`select estado from public.suscripciones where alumno_id='${idAlumno1}'`) === "cancelada" &&
      sql(`select estado from public.pagos_stripe where id='${pagoId1}'`) === "reembolsado",
  );

  console.log("── Cobro mensual automático (suscripción) ──");
  const tDueno = await entrar("dueno@prueba.itaca.test");
  const idHijo = hijo;
  comprueba(
    "El primer cobro mensual (aviso de suscripción) activó la cuota del hijo, sin fecha de fin",
    sql(`select proveedor_pago||'/'||referencia_externa||'/'||estado||'/'||payment_status||'/'||coalesce(fecha_fin::text,'sin fin') from public.suscripciones where alumno_id='${idHijo}'`) ===
      "stripe/sub_local_3/activa/active/sin fin",
    sql(`select proveedor_pago||'/'||referencia_externa||'/'||estado||'/'||payment_status||'/'||coalesce(fecha_fin::text,'sin fin') from public.suscripciones where alumno_id='${idHijo}'`),
  );
  await webhook(evento("customer.subscription.updated", { id: "sub_local_3", object: "subscription", status: "past_due" }));
  comprueba(
    "Stripe dice «impagada» (tras sus reintentos): la cuota refleja past_due",
    sql(`select payment_status from public.suscripciones where referencia_externa='sub_local_3'`) === "past_due",
  );
  await webhook(evento("customer.subscription.updated", { id: "sub_local_3", object: "subscription", status: "active" }));
  comprueba(
    "Stripe vuelve a cobrar: la cuota vuelve a active",
    sql(`select payment_status from public.suscripciones where referencia_externa='sub_local_3'`) === "active",
  );

  // Baja desde la app → se corta en Stripe. Solo el Dueño.
  const llamar = (token, f, cuerpo) =>
    fetch(`${FUNCIONES_URL || URL_API + "/functions/v1"}/${f}`, {
      method: "POST",
      headers: { apikey: ANON, Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
      body: JSON.stringify(cuerpo),
    }).then(async (r) => ({ estado: r.status, cuerpo: await r.json().catch(() => ({})) }));
  const porAlumno = await llamar(tTutor, "stripe-cancelar-suscripcion", { alumno_id: idHijo });
  comprueba("Un alumno/tutor NO puede cancelar el cobro (403)", porAlumno.estado === 403, JSON.stringify(porAlumno));
  const porDueno = await llamar(tDueno, "stripe-cancelar-suscripcion", { alumno_id: idHijo });
  comprueba("El Dueño sí: se corta en Stripe (200, 1 cancelada)", porDueno.estado === 200 && porDueno.cuerpo.cancelled === 1, JSON.stringify(porDueno));
  const sinCobro = await llamar(tDueno, "stripe-cancelar-suscripcion", { alumno_id: idAlumno1 });
  comprueba("Un alumno sin cobro automático: 200 y nada que cancelar", sinCobro.estado === 200 && sinCobro.cuerpo.cancelled === 0, JSON.stringify(sinCobro));

  // Baja desde Stripe → baja en la app.
  const w9 = await webhook(evento("customer.subscription.deleted", { id: "sub_local_3", object: "subscription", status: "canceled" }));
  comprueba("Stripe avisa de la cancelación (200)", w9.estado === 200, w9.texto);
  comprueba(
    "El alumno pasa a baja en la app y la cuota queda cancelada",
    sql(`select estado from public.profiles where id='${idHijo}'`) === "baja" &&
      sql(`select estado from public.suscripciones where referencia_externa='sub_local_3'`) === "cancelada",
  );

  console.log("── Funciones retiradas ──");
  for (const f of ["stripe-create-tarifa-subscription", "stripe-cancel-tarifa-subscription", "stripe-create-tienda-payment"]) {
    const r = await fetch(`${FUNCIONES_URL || URL_API + "/functions/v1"}/${f}`, {
      method: "POST",
      headers: { apikey: ANON, Authorization: `Bearer ${tAlumno1}`, "Content-Type": "application/json" },
      body: "{}",
    });
    comprueba(`${f} responde «no disponible» (410)`, r.status === 410, r.status);
  }

  console.log(`\n${ok} bien, ${mal} mal`);
  process.exit(mal ? 1 : 0);
})().catch((e) => {
  console.error("ERROR", e);
  process.exit(2);
});
