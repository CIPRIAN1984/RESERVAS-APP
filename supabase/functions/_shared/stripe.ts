import Stripe from "npm:stripe@17";

/**
 * Platform account client — used to create/manage each academia's connected account.
 *
 * `STRIPE_API_HOST`/`STRIPE_API_PORT`/`STRIPE_API_PROTOCOL` solo existen para
 * apuntar a un servidor de pruebas local (stripe-mock); en un despliegue real
 * no se definen y se habla con api.stripe.com.
 */
export function createStripeClient(): Stripe {
  const host = Deno.env.get("STRIPE_API_HOST");
  return new Stripe(Deno.env.get("STRIPE_SECRET_KEY")!, {
    ...(host
      ? {
        host,
        port: Deno.env.get("STRIPE_API_PORT") ?? "12111",
        protocol: (Deno.env.get("STRIPE_API_PROTOCOL") ?? "http") as
          | "http"
          | "https",
      }
      : {}),
    // Fijada a la que exige el paquete `stripe@17` resuelto hoy — nunca se
    // había comprobado con `deno check` (no estaba en el CI) y llevaba
    // pinned una versión de API vieja que ya no compilaba contra el propio
    // paquete. Si el día de mañana `stripe@17` resuelve un parche que pida
    // otra distinta, `deno check` en CI lo avisará igual que ha avisado
    // ahora, en vez de fallar en silencio al desplegar.
    apiVersion: "2025-02-24.acacia",
    httpClient: Stripe.createFetchHttpClient(),
  });
}

/** Maps an Account's onboarding fields to our `academias.stripe_onboarding_status` enum. */
export function onboardingStatusFor(
  account: Stripe.Account,
): "not_started" | "pending" | "complete" {
  if (!account.details_submitted) return "pending";
  return account.charges_enabled ? "complete" : "pending";
}

/**
 * Dónde se cobra. Con una sola academia cuya cuenta de Stripe ES la de la
 * plataforma (`STRIPE_COBRO_DIRECTO=true`) se cobra directamente en ella. Si
 * no, la academia cobra en su cuenta conectada (Stripe Connect) y tiene que
 * haber terminado el alta.
 */
export function cuentaDeCobro(
  academia: {
    stripe_account_id: string | null;
    stripe_charges_enabled: boolean | null;
  } | null,
): { ok: true; opciones?: { stripeAccount: string } } | { ok: false } {
  if (Deno.env.get("STRIPE_COBRO_DIRECTO") === "true") return { ok: true };
  if (!academia?.stripe_account_id || !academia.stripe_charges_enabled) {
    return { ok: false };
  }
  return { ok: true, opciones: { stripeAccount: academia.stripe_account_id } };
}
