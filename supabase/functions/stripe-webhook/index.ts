// Single endpoint for all Stripe events — both platform-account events and
// Connected-account events (the Stripe Dashboard webhook config must have
// "Listen to events on Connected accounts" enabled for the latter to arrive).
// Deployed with --no-verify-jwt: security comes from the Stripe-Signature
// check below, not a Supabase JWT (Stripe can't send one).
import Stripe from "npm:stripe@17";
import { createAdminClient, jsonResponse } from "../_shared/utils.ts";
import { createStripeClient, onboardingStatusFor } from "../_shared/stripe.ts";

const webhookSecret = Deno.env.get("STRIPE_WEBHOOK_SECRET")!;

Deno.serve(async (req) => {
  const signature = req.headers.get("Stripe-Signature");
  if (!signature) {
    return new Response("Missing Stripe-Signature header", { status: 400 });
  }

  const body = await req.text();
  const stripe = createStripeClient();

  let event: Stripe.Event;
  try {
    // Async variant required: Deno's SubtleCrypto (used for signature
    // verification) is async-only, unlike Node's.
    event = await stripe.webhooks.constructEventAsync(body, signature, webhookSecret);
  } catch (error) {
    console.error("Firma de webhook de Stripe inválida:", error);
    return new Response("Invalid signature", { status: 400 });
  }

  const admin = createAdminClient();

  // Idempotency: only mark an event as processed *after* handling it
  // successfully, so a failed attempt can be retried by Stripe rather than
  // silently swallowed by our own dedup check.
  const { data: alreadyProcessed } = await admin
    .from("stripe_webhook_events")
    .select("id")
    .eq("id", event.id)
    .maybeSingle();
  if (alreadyProcessed) {
    return jsonResponse({ received: true, deduped: true });
  }

  try {
    switch (event.type) {
      case "account.updated": {
        const account = event.data.object as Stripe.Account;
        await admin
          .from("academias")
          .update({
            stripe_onboarding_status: onboardingStatusFor(account),
            stripe_charges_enabled: account.charges_enabled ?? false,
          })
          .eq("stripe_account_id", account.id);
        break;
      }
      case "payment_intent.succeeded": {
        const pi = event.data.object as Stripe.PaymentIntent;
        const pedidoId = pi.metadata?.pedido_id;
        if (pedidoId) {
          await admin
            .from("pedidos")
            .update({ payment_status: "succeeded", estado: "reservado" })
            .eq("id", pedidoId);
        }
        break;
      }
      case "payment_intent.payment_failed": {
        const pi = event.data.object as Stripe.PaymentIntent;
        const pedidoId = pi.metadata?.pedido_id;
        if (pedidoId) {
          await admin.from("pedidos").update({ payment_status: "failed" }).eq("id", pedidoId);
        }
        break;
      }
      case "payment_intent.canceled": {
        const pi = event.data.object as Stripe.PaymentIntent;
        const pedidoId = pi.metadata?.pedido_id;
        if (pedidoId) {
          await admin
            .from("pedidos")
            .update({ payment_status: "canceled", estado: "cancelado" })
            .eq("id", pedidoId);
        }
        break;
      }
      case "invoice.payment_succeeded": {
        const invoice = event.data.object as Stripe.Invoice;
        const subscriptionId = invoice.subscription as string | null;
        if (subscriptionId) {
          await admin
            .from("suscripciones")
            .update({ estado: "activa", payment_status: "active" })
            .eq("referencia_externa", subscriptionId);
        }
        break;
      }
      case "customer.subscription.updated": {
        const subscription = event.data.object as Stripe.Subscription;
        const paymentStatus = subscription.status; // active | past_due | canceled | unpaid | ...
        const estado = paymentStatus === "active" ? "activa" : paymentStatus === "canceled" ? "cancelada" : undefined;
        await admin
          .from("suscripciones")
          .update({
            payment_status: ["active", "past_due", "canceled", "unpaid"].includes(paymentStatus)
              ? paymentStatus
              : "unpaid",
            ...(estado ? { estado } : {}),
            ...(paymentStatus === "canceled" ? { fecha_fin: new Date().toISOString() } : {}),
          })
          .eq("referencia_externa", subscription.id);
        break;
      }
      case "customer.subscription.deleted": {
        const subscription = event.data.object as Stripe.Subscription;
        await admin
          .from("suscripciones")
          .update({ estado: "cancelada", payment_status: "canceled", fecha_fin: new Date().toISOString() })
          .eq("referencia_externa", subscription.id);
        break;
      }
      default:
        break;
    }

    await admin.from("stripe_webhook_events").insert({ id: event.id, type: event.type });
    return jsonResponse({ received: true });
  } catch (error) {
    console.error(`Error procesando el evento ${event.type} (${event.id}):`, error);
    // Non-2xx so Stripe retries this delivery later.
    return new Response("Internal error handling webhook", { status: 500 });
  }
});
