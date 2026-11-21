// Corta en Stripe el cobro automático de un alumno cuando el Dueño lo da de
// baja en la app (decisión de Cipri, 21/11/2026: la baja vale en los dos
// sentidos). SOLO el Dueño (o el Administrador de plataforma): el alumno no
// puede cancelar su cuota.
//
// Cancela en el acto y no devuelve el mes ya pagado. Es idempotente: si no hay
// cobro automático, o ya estaba cancelado, responde bien sin hacer nada.
// La baja del alumno en la app la hace después `dar_de_baja_alumno`; y el aviso
// «suscripción cancelada» que manda Stripe no repite nada (la función de base de
// datos que lo recibe ignora una cuota ya cerrada).
import {
  createAdminClient,
  getCallerProfile,
  jsonResponse,
  logEvent,
} from "../_shared/utils.ts";
import { createStripeClient } from "../_shared/stripe.ts";

Deno.serve(async (req) => {
  try {
    if (req.method !== "POST") {
      return jsonResponse({ error: "Método no permitido." }, 405);
    }
    const caller = await getCallerProfile(req);
    if (!caller) return jsonResponse({ error: "No autorizado." }, 401);
    if (caller.rol !== "dueño" && caller.rol !== "administrador") {
      return jsonResponse({
        error: "Solo el dueño de la academia puede dar de baja.",
      }, 403);
    }

    const body = (await req.json().catch(() => null)) as
      | { alumno_id?: string }
      | null;
    if (!body?.alumno_id) {
      return jsonResponse({ error: "Falta alumno_id." }, 400);
    }

    const admin = createAdminClient();
    const { data: alumno } = await admin.from("profiles")
      .select("academia_id").eq("id", body.alumno_id).maybeSingle();
    if (
      !alumno ||
      (caller.rol !== "administrador" &&
        alumno.academia_id !== caller.academiaId)
    ) {
      return jsonResponse({ error: "Ese alumno no es de tu academia." }, 403);
    }

    const { data: cuotas } = await admin.from("suscripciones")
      .select("id, referencia_externa")
      .eq("alumno_id", body.alumno_id)
      .eq("proveedor_pago", "stripe")
      .like("referencia_externa", "sub\\_%")
      .in("estado", [
        "activa",
        "pendiente_pago",
        "pausada",
        "programada",
        "prueba",
      ]);
    if (!cuotas?.length) return jsonResponse({ cancelled: 0 });

    // Dónde está la suscripción: la cuenta de la academia (Connect) o la
    // propia (cobro directo). No depende del interruptor de «cobro activado»:
    // aunque se apague, una baja tiene que poder cortar el cobro.
    const { data: academia } = await admin.from("academias")
      .select("stripe_account_id").eq("id", alumno.academia_id).single();
    const opciones = Deno.env.get("STRIPE_COBRO_DIRECTO") === "true"
      ? undefined
      : academia?.stripe_account_id
      ? { stripeAccount: academia.stripe_account_id as string }
      : null;
    if (opciones === null) {
      return jsonResponse({
        error:
          "La academia no tiene cuenta de cobro: no se puede cortar el cobro en Stripe.",
      }, 409);
    }

    const stripe = createStripeClient();
    let canceladas = 0;
    for (const cuota of cuotas) {
      try {
        await stripe.subscriptions.cancel(
          cuota.referencia_externa as string,
          {},
          opciones,
        );
        canceladas++;
      } catch (error) {
        // Ya no existe o ya estaba cancelada en Stripe: la baja puede seguir.
        const e = error as { code?: string; statusCode?: number };
        if (e.code === "resource_missing" || e.statusCode === 404) continue;
        throw error;
      }
    }
    return jsonResponse({ cancelled: canceladas });
  } catch (error) {
    logEvent(
      "error",
      "stripe-cancelar-suscripcion",
      "Error cancelando el cobro",
      {
        error: String(error),
      },
    );
    return jsonResponse({
      error:
        "No se ha podido cortar el cobro en Stripe. No se ha dado de baja.",
    }, 502);
  }
});
