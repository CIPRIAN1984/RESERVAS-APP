// Pago único de una cuota con tarjeta, con la página de pago de Stripe
// (Checkout). Un pago = un periodo de la tarifa (un mes, un bono, un día
// suelto): NO crea ninguna suscripción recurrente.
//
// Esta función solo PREPARA el pago. La cuota la activa el webhook cuando
// Stripe confirma el cobro (`stripe-webhook`), nunca porque el navegador
// vuelva diciendo «pago correcto».
import {
  createAdminClient,
  getCallerProfile,
  jsonResponse,
  logEvent,
} from "../_shared/utils.ts";
import { createStripeClient, cuentaDeCobro } from "../_shared/stripe.ts";

const MINUTOS_SESION = 35;

Deno.serve(async (req) => {
  try {
    const caller = await getCallerProfile(req);
    if (!caller) return jsonResponse({ error: "No autorizado." }, 401);

    const body = (await req.json().catch(() => null)) as
      | { tarifa_id?: string; alumno_id?: string }
      | null;
    const tarifaId = body?.tarifa_id;
    if (!tarifaId) return jsonResponse({ error: "Falta tarifa_id." }, 400);
    // Sin alumno_id se paga la cuota propia; un tutor manda la de su hijo.
    const alumnoId = body?.alumno_id ?? caller.userId;

    const appUrl = Deno.env.get("APP_URL")?.replace(/\/$/, "");
    if (!appUrl) {
      logEvent("error", "stripe-checkout-tarifa", "APP_URL sin configurar");
      return jsonResponse({ error: "Los pagos no están configurados." }, 503);
    }

    const admin = createAdminClient();

    // ¿La academia puede cobrar? Antes de abrir ningún pago.
    const { data: persona } = await admin.from("profiles")
      .select("academia_id").eq("id", alumnoId).maybeSingle();
    const { data: academia } = persona
      ? await admin.from("academias")
        .select("stripe_account_id, stripe_charges_enabled")
        .eq("id", persona.academia_id).single()
      : { data: null };
    const cuenta = cuentaDeCobro(academia);
    if (!cuenta.ok) {
      return jsonResponse({
        error: "Esta academia todavía no ha configurado los cobros.",
      }, 409);
    }

    // Quién puede pagar qué, y cuánto, lo decide la base de datos.
    const preparar = () =>
      admin.rpc("preparar_pago_stripe", {
        p_quien: caller.userId,
        p_alumno_id: alumnoId,
        p_tarifa_id: tarifaId,
      });
    type Preparado = {
      pago_id: string;
      importe_centimos: number;
      tarifa_nombre: string;
      reutilizado: boolean;
    };
    const { data: preparado, error: errorPreparar } = await preparar();
    if (errorPreparar) {
      return jsonResponse({ error: errorPreparar.message }, 409);
    }
    let pago = (preparado as Preparado[])[0];

    const stripe = createStripeClient();

    // Un pago abierto se reutiliza si su página de pago sigue válida.
    if (pago.reutilizado) {
      const { data: previo } = await admin.from("pagos_stripe")
        .select("checkout_session_id").eq("id", pago.pago_id).single();
      if (previo?.checkout_session_id) {
        const sesion = await stripe.checkout.sessions.retrieve(
          previo.checkout_session_id,
          undefined,
          cuenta.opciones,
        );
        if (sesion.status === "open" && sesion.url) {
          return jsonResponse({ url: sesion.url, pago_id: pago.pago_id });
        }
        // Caducada o ya pagada: se cierra y se abre una nueva.
        await admin.rpc("cerrar_pago_stripe", {
          p_session_id: previo.checkout_session_id,
          p_estado: "expirado",
          p_motivo: "La página de pago ya no estaba abierta.",
        });
        const { data: otro, error: errorOtro } = await preparar();
        if (errorOtro) return jsonResponse({ error: errorOtro.message }, 409);
        pago = (otro as Preparado[])[0];
      }
    }

    const sesion = await stripe.checkout.sessions.create(
      {
        mode: "payment",
        locale: "es",
        client_reference_id: pago.pago_id,
        customer_email: caller.email ?? undefined,
        line_items: [
          {
            quantity: 1,
            price_data: {
              currency: "eur",
              unit_amount: pago.importe_centimos,
              product_data: { name: pago.tarifa_nombre },
            },
          },
        ],
        metadata: {
          pago_id: pago.pago_id,
          alumno_id: alumnoId,
          tarifa_id: tarifaId,
        },
        payment_intent_data: { metadata: { pago_id: pago.pago_id } },
        expires_at: Math.floor(Date.now() / 1000) + MINUTOS_SESION * 60,
        // La vuelta solo es para enseñar el resultado; no activa nada.
        success_url: `${appUrl}/#/pago?pago=${pago.pago_id}`,
        cancel_url: `${appUrl}/#/pago?pago=${pago.pago_id}&cancelado=1`,
      },
      cuenta.opciones,
    );

    // Si no se guarda la sesión, un cobro posterior no se podría asociar a este
    // pago: es preferible fallar ahora que cobrar sin poder activar.
    const { error: errorGuardar } = await admin.rpc("guardar_sesion_stripe", {
      p_pago_id: pago.pago_id,
      p_session_id: sesion.id,
    });
    if (errorGuardar) throw new Error(errorGuardar.message);

    return jsonResponse({ url: sesion.url, pago_id: pago.pago_id });
  } catch (error) {
    logEvent("error", "stripe-checkout-tarifa", "Error creando el pago", {
      error: String(error),
    });
    return jsonResponse({ error: "No se ha podido iniciar el pago." }, 500);
  }
});
