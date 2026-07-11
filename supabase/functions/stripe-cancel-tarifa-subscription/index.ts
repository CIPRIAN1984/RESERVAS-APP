// Cancels the caller's Stripe Billing subscription on the academy's
// connected account. Stripe is changed first; Postgres is reconciled only
// after Stripe confirms the cancellation.
import {
  createAdminClient,
  createUserClient,
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

    const body = (await req.json().catch(() => null)) as {
      suscripcion_id?: string;
    } | null;
    const suscripcionId = body?.suscripcion_id;
    if (!suscripcionId) {
      return jsonResponse({ error: "Falta suscripcion_id." }, 400);
    }

    const userClient = createUserClient(req.headers.get("Authorization")!);
    const { data: suscripcion, error: suscripcionError } = await userClient
      .from("suscripciones")
      .select(
        "id, alumno_id, academia_id, estado, proveedor_pago, referencia_externa",
      )
      .eq("id", suscripcionId)
      .maybeSingle();

    if (suscripcionError) throw suscripcionError;
    if (!suscripcion) {
      return jsonResponse({ error: "Suscripción no encontrada." }, 404);
    }
    if (suscripcion.alumno_id !== caller.userId) {
      return jsonResponse({ error: "No puedes cancelar esta suscripción." }, 403);
    }
    if (["cancelada", "expirada"].includes(suscripcion.estado)) {
      return jsonResponse({ cancelled: true, already_cancelled: true });
    }
    if (
      suscripcion.proveedor_pago !== "stripe" ||
      !suscripcion.referencia_externa
    ) {
      return jsonResponse(
        { error: "Esta suscripción requiere cancelación administrativa." },
        409,
      );
    }

    const admin = createAdminClient();
    const { data: academia, error: academiaError } = await admin
      .from("academias")
      .select("stripe_account_id")
      .eq("id", suscripcion.academia_id)
      .single();

    if (academiaError) throw academiaError;
    if (!academia?.stripe_account_id) {
      return jsonResponse(
        { error: "La academia no tiene una cuenta de cobro configurada." },
        409,
      );
    }

    const stripe = createStripeClient();
    const stripeAccount = academia.stripe_account_id as string;
    const stripeSubscription = await stripe.subscriptions.retrieve(
      suscripcion.referencia_externa,
      { stripeAccount },
    );

    if (stripeSubscription.status !== "canceled") {
      await stripe.subscriptions.cancel(suscripcion.referencia_externa, {
        stripeAccount,
      });
    }

    const endedAt = new Date().toISOString();
    const { error: updateError } = await admin
      .from("suscripciones")
      .update({
        estado: "cancelada",
        payment_status: "canceled",
        fecha_fin: endedAt,
      })
      .eq("id", suscripcion.id)
      .eq("alumno_id", caller.userId);

    if (updateError) throw updateError;

    logEvent(
      "info",
      "stripe-cancel-tarifa-subscription",
      "Suscripción cancelada",
      {
        suscripcion_id: suscripcion.id,
        academia_id: suscripcion.academia_id,
        alumno_id: caller.userId,
      },
    );

    return jsonResponse({ cancelled: true, ended_at: endedAt });
  } catch (error) {
    logEvent(
      "error",
      "stripe-cancel-tarifa-subscription",
      "Error cancelando suscripción",
      { error: String(error) },
    );
    return jsonResponse(
      { error: "No se ha podido cancelar la suscripción." },
      500,
    );
  }
});
