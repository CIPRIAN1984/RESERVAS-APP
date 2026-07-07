// Called when an alumno subscribes to a tarifa. Creates (or reuses) a Stripe
// Customer and a Subscription directly on the academia's connected account,
// using inline price_data (never a cached Price — so alumnos already
// subscribed aren't affected if the tarifa's price changes later).
import Stripe from "npm:stripe@17";
import { createAdminClient, createUserClient, getCallerProfile, jsonResponse } from "../_shared/utils.ts";
import { createStripeClient } from "../_shared/stripe.ts";

const intervalFor = (periodicidad: string): { interval: Stripe.PriceCreateParams.Recurring.Interval; interval_count: number } => {
  switch (periodicidad) {
    case "mensual":
      return { interval: "month", interval_count: 1 };
    case "trimestral":
      return { interval: "month", interval_count: 3 };
    case "anual":
      return { interval: "year", interval_count: 1 };
    default:
      throw new Error(`Periodicidad desconocida: ${periodicidad}`);
  }
};

Deno.serve(async (req) => {
  try {
    const caller = await getCallerProfile(req);
    if (!caller) return jsonResponse({ error: "No autorizado." }, 401);

    const body = (await req.json().catch(() => null)) as { tarifa_id?: string } | null;
    const tarifaId = body?.tarifa_id;
    if (!tarifaId) return jsonResponse({ error: "Falta tarifa_id." }, 400);

    const userClient = createUserClient(req.headers.get("Authorization")!);
    const { data: tarifa, error: tarifaError } = await userClient
      .from("tarifas")
      .select("id, academia_id, nombre, precio, periodicidad, activo")
      .eq("id", tarifaId)
      .single();
    if (tarifaError || !tarifa || !tarifa.activo) {
      return jsonResponse({ error: "Tarifa no encontrada." }, 404);
    }

    const admin = createAdminClient();
    const { data: academia } = await admin
      .from("academias")
      .select("stripe_account_id, stripe_charges_enabled")
      .eq("id", tarifa.academia_id)
      .single();
    if (!academia?.stripe_account_id || !academia.stripe_charges_enabled) {
      return jsonResponse({ error: "Esta academia todavía no ha configurado los cobros." }, 409);
    }

    const { data: activa } = await userClient
      .from("suscripciones")
      .select("id, tarifa_id")
      .eq("alumno_id", caller.userId)
      .eq("estado", "activa")
      .maybeSingle();
    if (activa && activa.tarifa_id !== tarifaId) {
      return jsonResponse(
        { error: "Ya tienes una suscripción activa. Cancélala antes de suscribirte a otra tarifa." },
        409,
      );
    }

    // Reuse an in-flight checkout if one already exists (e.g. the alumno
    // backed out of a previous PaymentSheet) instead of hitting the unique
    // "one active/pending subscription per alumno" index.
    const { data: pendiente } = await userClient
      .from("suscripciones")
      .select("id, tarifa_id, referencia_externa")
      .eq("alumno_id", caller.userId)
      .eq("estado", "pendiente_pago")
      .maybeSingle();

    const stripe = createStripeClient();
    const stripeAccount = academia.stripe_account_id;

    if (pendiente) {
      if (pendiente.tarifa_id !== tarifaId) {
        return jsonResponse(
          { error: "Ya tienes un pago de suscripción en curso para otra tarifa. Complétalo o cancélalo antes de suscribirte a esta." },
          409,
        );
      }
      const subscription = await stripe.subscriptions.retrieve(pendiente.referencia_externa!, {
        expand: ["latest_invoice.payment_intent"],
        stripeAccount,
      });
      const invoice = subscription.latest_invoice as Stripe.Invoice;
      const paymentIntent = invoice.payment_intent as Stripe.PaymentIntent;
      return jsonResponse({ client_secret: paymentIntent.client_secret, stripe_account_id: stripeAccount });
    }

    // Reuse a previous Customer for this alumno on this connected account if
    // one exists (from an earlier, now-cancelled subscription).
    const { data: previa } = await userClient
      .from("suscripciones")
      .select("stripe_customer_id")
      .eq("alumno_id", caller.userId)
      .eq("academia_id", tarifa.academia_id)
      .not("stripe_customer_id", "is", null)
      .order("created_at", { ascending: false })
      .limit(1)
      .maybeSingle();

    const customer = previa?.stripe_customer_id
      ? { id: previa.stripe_customer_id }
      : await stripe.customers.create(
          { email: caller.email ?? undefined, metadata: { alumno_id: caller.userId } },
          { stripeAccount },
        );

    const { interval, interval_count } = intervalFor(tarifa.periodicidad);
    const amountCents = Math.round(Number(tarifa.precio) * 100);

    // Subscription items only accept price_data with a Product *id* (unlike
    // one-off PaymentIntents/Invoice items, which allow inline product_data)
    // — reuse a Product per tarifa instead of creating one on every checkout.
    const existingProducts = await stripe.products.search(
      { query: `metadata['tarifa_id']:'${tarifa.id}'`, limit: 1 },
      { stripeAccount },
    );
    const product = existingProducts.data[0] ??
      (await stripe.products.create(
        { name: tarifa.nombre, metadata: { tarifa_id: tarifa.id } },
        { stripeAccount },
      ));

    const subscription = await stripe.subscriptions.create(
      {
        customer: customer.id,
        items: [
          {
            price_data: {
              currency: "eur",
              unit_amount: amountCents,
              recurring: { interval, interval_count },
              product: product.id,
            },
          },
        ],
        payment_behavior: "default_incomplete",
        payment_settings: { save_default_payment_method: "on_subscription" },
        expand: ["latest_invoice.payment_intent"],
        metadata: { tarifa_id: tarifa.id, alumno_id: caller.userId },
      },
      { stripeAccount },
    );

    const { error: insertError } = await admin.from("suscripciones").insert({
      alumno_id: caller.userId,
      tarifa_id: tarifa.id,
      stripe_customer_id: customer.id,
      referencia_externa: subscription.id,
    });
    if (insertError) {
      // Roll back the Stripe subscription so we don't leave an orphaned one.
      await stripe.subscriptions.cancel(subscription.id, { stripeAccount });
      throw insertError;
    }

    const invoice = subscription.latest_invoice as Stripe.Invoice;
    const paymentIntent = invoice.payment_intent as Stripe.PaymentIntent;
    return jsonResponse({ client_secret: paymentIntent.client_secret, stripe_account_id: stripeAccount });
  } catch (error) {
    console.error("stripe-create-tarifa-subscription error:", error);
    return jsonResponse({ error: "No se ha podido iniciar la suscripción." }, 500);
  }
});
