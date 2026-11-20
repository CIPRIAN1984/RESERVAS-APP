// Single endpoint for all Stripe events — both platform-account events and
// Connected-account events (the Stripe Dashboard webhook config must have
// "Listen to events on Connected accounts" enabled for the latter to arrive).
// Deployed with --no-verify-jwt: security comes from the Stripe-Signature
// check below, not a Supabase JWT (Stripe can't send one).
import Stripe from "npm:stripe@17";
import { createAdminClient, jsonResponse, logEvent } from "../_shared/utils.ts";
import { createStripeClient, onboardingStatusFor } from "../_shared/stripe.ts";

const webhookSecret = Deno.env.get("STRIPE_WEBHOOK_SECRET")!;

/**
 * Llama a una función de la base de datos del cobro con tarjeta. Si falla,
 * se lanza el error para que la entrega devuelva un 500 y Stripe la repita.
 * La excepción es un pago que no es nuestro (otra sesión de la misma cuenta):
 * se ignora para no repetirlo eternamente.
 */
async function llamarBd(
  admin: ReturnType<typeof createAdminClient>,
  funcion: string,
  parametros: Record<string, unknown>,
): Promise<void> {
  const { error } = await admin.rpc(funcion, parametros);
  if (error && !error.message.includes("Pago desconocido")) {
    throw new Error(`${funcion}: ${error.message}`);
  }
  if (error) {
    logEvent("warn", "stripe-webhook", "Pago que no es de esta app", {
      funcion,
    });
  }
}

const idDe = (x: string | { id: string } | null | undefined): string | null =>
  typeof x === "string" ? x : x?.id ?? null;

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
    event = await stripe.webhooks.constructEventAsync(
      body,
      signature,
      webhookSecret,
    );
  } catch (error) {
    logEvent("warn", "stripe-webhook", "Firma de webhook inválida", {
      error: String(error),
    });
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
      // ── Pago único de una cuota (Checkout) ──────────────────────────────
      // La cuota se activa SOLO aquí, con la confirmación firmada de Stripe.
      case "checkout.session.completed":
      case "checkout.session.async_payment_succeeded": {
        const session = event.data.object as Stripe.Checkout.Session;
        if (session.mode !== "payment" || !session.metadata?.pago_id) break;
        // Pagos que tardan (p. ej. domiciliación): «completed» llega con el
        // cobro todavía pendiente; se activa con «async_payment_succeeded».
        if (session.payment_status !== "paid") break;
        await llamarBd(admin, "confirmar_pago_stripe", {
          p_session_id: session.id,
          p_payment_intent: idDe(session.payment_intent),
          p_importe_centimos: session.amount_total ?? 0,
          p_moneda: session.currency ?? "",
        });
        break;
      }
      case "checkout.session.async_payment_failed": {
        const session = event.data.object as Stripe.Checkout.Session;
        if (!session.metadata?.pago_id) break;
        await llamarBd(admin, "cerrar_pago_stripe", {
          p_session_id: session.id,
          p_estado: "fallido",
          p_motivo: "El pago no se ha completado.",
        });
        break;
      }
      case "checkout.session.expired": {
        // Abandonado: la persona no llegó a pagar.
        const session = event.data.object as Stripe.Checkout.Session;
        if (!session.metadata?.pago_id) break;
        await llamarBd(admin, "cerrar_pago_stripe", {
          p_session_id: session.id,
          p_estado: "expirado",
          p_motivo: "La página de pago caducó sin pagar.",
        });
        break;
      }
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
        // Un intento rechazado de pagar una cuota: se anota el motivo; el
        // pago sigue abierto porque la persona puede reintentar.
        if (pi.metadata?.pago_id) {
          await llamarBd(admin, "anotar_intento_fallido_stripe", {
            p_pago_id: pi.metadata.pago_id,
            p_motivo: pi.last_payment_error?.message ?? "",
          });
        }
        const pedidoId = pi.metadata?.pedido_id;
        if (pedidoId) {
          await admin.from("pedidos").update({ payment_status: "failed" }).eq(
            "id",
            pedidoId,
          );
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
      case "charge.refunded": {
        // Un pedido pagado que se reembolsa: lo cancelamos y el trigger
        // reponer_stock_al_cancelar devuelve el stock. El pedido se localiza
        // por su PaymentIntent (charge.payment_intent).
        const charge = event.data.object as Stripe.Charge;
        const paymentIntentId = typeof charge.payment_intent === "string"
          ? charge.payment_intent
          : charge.payment_intent?.id;
        if (paymentIntentId) {
          // Si era el pago de una cuota: una devolución total la cancela.
          await llamarBd(admin, "registrar_devolucion_stripe", {
            p_payment_intent: paymentIntentId,
            p_devuelto_centimos: charge.amount_refunded,
          });
          await admin
            .from("pedidos")
            .update({ payment_status: "refunded", estado: "cancelado" })
            .eq("stripe_payment_intent_id", paymentIntentId)
            .in("estado", ["reservado", "confirmado", "entregado"]);
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
            .eq("referencia_externa", subscriptionId)
            .in("estado", ["pendiente_pago", "activa"]);
        }
        break;
      }
      case "customer.subscription.updated": {
        const subscription = event.data.object as Stripe.Subscription;
        const paymentStatus = subscription.status; // active | past_due | canceled | unpaid | ...
        const estado = paymentStatus === "active"
          ? "activa"
          : paymentStatus === "canceled"
          ? "cancelada"
          : undefined;
        let updateQuery = admin
          .from("suscripciones")
          .update({
            payment_status:
              ["active", "past_due", "canceled", "unpaid"].includes(
                  paymentStatus,
                )
                ? paymentStatus
                : "unpaid",
            ...(estado ? { estado } : {}),
            ...(paymentStatus === "canceled"
              ? { fecha_fin: new Date().toISOString() }
              : {}),
          })
          .eq("referencia_externa", subscription.id);
        if (paymentStatus !== "canceled") {
          updateQuery = updateQuery.in("estado", ["pendiente_pago", "activa"]);
        }
        await updateQuery;
        break;
      }
      case "customer.subscription.deleted": {
        const subscription = event.data.object as Stripe.Subscription;
        await admin
          .from("suscripciones")
          .update({
            estado: "cancelada",
            payment_status: "canceled",
            fecha_fin: new Date().toISOString(),
          })
          .eq("referencia_externa", subscription.id);
        break;
      }
      default:
        break;
    }

    await admin.from("stripe_webhook_events").insert({
      id: event.id,
      type: event.type,
    });
    logEvent("info", "stripe-webhook", "Evento procesado", {
      event_id: event.id,
      event_type: event.type,
    });
    return jsonResponse({ received: true });
  } catch (error) {
    logEvent("error", "stripe-webhook", "Error procesando evento", {
      event_id: event.id,
      event_type: event.type,
      error: String(error),
    });
    // Non-2xx so Stripe retries this delivery later.
    return new Response("Internal error handling webhook", { status: 500 });
  }
});
