// Called when an alumno pays for a tienda order. Creates a PaymentIntent
// directly on the academia's connected account (direct charge — the money
// never touches the platform account).
import Stripe from "npm:stripe@17";
import { createAdminClient, createUserClient, getCallerProfile, jsonResponse } from "../_shared/utils.ts";
import { createStripeClient } from "../_shared/stripe.ts";

Deno.serve(async (req) => {
  try {
    const caller = await getCallerProfile(req);
    if (!caller) return jsonResponse({ error: "No autorizado." }, 401);

    const body = (await req.json().catch(() => null)) as { pedido_id?: string } | null;
    const pedidoId = body?.pedido_id;
    if (!pedidoId) return jsonResponse({ error: "Falta pedido_id." }, 400);

    // RLS-scoped read: only returns a row if the caller is allowed to see it.
    const userClient = createUserClient(req.headers.get("Authorization")!);
    const { data: pedido, error: pedidoError } = await userClient
      .from("pedidos")
      .select("id, alumno_id, academia_id, cantidad, precio_snapshot, estado, stripe_payment_intent_id")
      .eq("id", pedidoId)
      .single();

    if (pedidoError || !pedido) {
      return jsonResponse({ error: "Pedido no encontrado." }, 404);
    }
    if (pedido.alumno_id !== caller.userId) {
      return jsonResponse({ error: "Este pedido no es tuyo." }, 403);
    }
    if (pedido.estado !== "pendiente_pago") {
      return jsonResponse({ error: "Este pedido ya no está pendiente de pago." }, 409);
    }

    const admin = createAdminClient();
    const { data: academia } = await admin
      .from("academias")
      .select("stripe_account_id, stripe_charges_enabled")
      .eq("id", pedido.academia_id)
      .single();

    if (!academia?.stripe_account_id || !academia.stripe_charges_enabled) {
      return jsonResponse({ error: "Esta academia todavía no ha configurado los cobros." }, 409);
    }

    const stripe = createStripeClient();
    const amountCents = Math.round(Number(pedido.precio_snapshot) * pedido.cantidad * 100);

    let paymentIntent: Stripe.PaymentIntent;
    if (pedido.stripe_payment_intent_id) {
      // Retry after e.g. the user backed out of a previous PaymentSheet.
      paymentIntent = await stripe.paymentIntents.retrieve(pedido.stripe_payment_intent_id, {
        stripeAccount: academia.stripe_account_id,
      });
    } else {
      paymentIntent = await stripe.paymentIntents.create(
        {
          amount: amountCents,
          currency: "eur",
          metadata: { pedido_id: pedido.id },
          // Redirect-based methods (Bizum, iDEAL, etc.) need a return_url we
          // haven't wired up for the mobile PaymentSheet flow — keep to
          // methods that complete entirely in-sheet (card and similar).
          automatic_payment_methods: { enabled: true, allow_redirects: "never" },
        },
        { stripeAccount: academia.stripe_account_id },
      );

      await admin
        .from("pedidos")
        .update({ stripe_payment_intent_id: paymentIntent.id, payment_status: "processing" })
        .eq("id", pedido.id);
    }

    return jsonResponse({
      client_secret: paymentIntent.client_secret,
      stripe_account_id: academia.stripe_account_id,
    });
  } catch (error) {
    console.error("stripe-create-tienda-payment error:", error);
    return jsonResponse({ error: "No se ha podido iniciar el pago." }, 500);
  }
});
