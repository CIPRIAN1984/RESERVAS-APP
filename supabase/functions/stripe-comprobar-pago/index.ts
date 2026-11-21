// Comprueba con Stripe el estado de un pago de cuota, para la pantalla a la
// que se vuelve tras pagar. Sirve de red de seguridad si el aviso del webhook
// tarda o se pierde.
//
// No se fía del navegador: pregunta DIRECTAMENTE a Stripe por la sesión y, si
// Stripe dice que está pagada, activa la cuota con la misma función que el
// webhook (`confirmar_pago_stripe`), que no duplica aunque lleguen las dos.
import {
  createAdminClient,
  createUserClient,
  getCallerProfile,
  jsonResponse,
  logEvent,
} from "../_shared/utils.ts";
import { createStripeClient, cuentaDeCobro } from "../_shared/stripe.ts";

Deno.serve(async (req) => {
  try {
    const caller = await getCallerProfile(req);
    if (!caller) return jsonResponse({ error: "No autorizado." }, 401);

    const body = (await req.json().catch(() => null)) as
      | { pago_id?: string }
      | null;
    if (!body?.pago_id) return jsonResponse({ error: "Falta pago_id." }, 400);

    // Con la sesión de quien pregunta: solo ve el pago si es suyo, de su hijo
    // o de su academia (si es el Dueño).
    const userClient = createUserClient(req.headers.get("Authorization")!);
    const { data: pago } = await userClient
      .from("pagos_stripe")
      .select("id, estado, checkout_session_id, academia_id")
      .eq("id", body.pago_id)
      .maybeSingle();
    if (!pago) return jsonResponse({ error: "Pago no encontrado." }, 404);

    if (pago.estado !== "creado" || !pago.checkout_session_id) {
      return jsonResponse({ estado: pago.estado });
    }

    const admin = createAdminClient();
    const { data: academia } = await admin
      .from("academias")
      .select("stripe_account_id, stripe_charges_enabled")
      .eq("id", pago.academia_id)
      .single();
    const cuenta = cuentaDeCobro(academia);
    if (!cuenta.ok) return jsonResponse({ estado: pago.estado });

    const sesion = await createStripeClient().checkout.sessions.retrieve(
      pago.checkout_session_id,
      undefined,
      cuenta.opciones,
    );

    if (sesion.payment_status === "paid") {
      const idDe = (x: unknown) =>
        typeof x === "string" ? x : (x as { id?: string } | null)?.id ?? null;
      const { error } = sesion.mode === "subscription"
        ? await admin.rpc("confirmar_suscripcion_stripe", {
          p_session_id: sesion.id,
          p_subscription_id: idDe(sesion.subscription),
          p_importe_centimos: sesion.amount_total ?? 0,
          p_moneda: sesion.currency ?? "",
        })
        : await admin.rpc("confirmar_pago_stripe", {
          p_session_id: sesion.id,
          p_payment_intent: idDe(sesion.payment_intent),
          p_importe_centimos: sesion.amount_total ?? 0,
          p_moneda: sesion.currency ?? "",
        });
      if (error) throw new Error(error.message);
    } else if (sesion.status === "expired") {
      await admin.rpc("cerrar_pago_stripe", {
        p_session_id: sesion.id,
        p_estado: "expirado",
        p_motivo: "La página de pago caducó sin pagar.",
      });
    }

    const { data: actual } = await userClient
      .from("pagos_stripe")
      .select("estado")
      .eq("id", pago.id)
      .single();
    return jsonResponse({ estado: actual?.estado ?? pago.estado });
  } catch (error) {
    logEvent("error", "stripe-comprobar-pago", "Error comprobando el pago", {
      error: String(error),
    });
    return jsonResponse({ error: "No se ha podido comprobar el pago." }, 500);
  }
});
