import Stripe from "npm:stripe@17";

/** Platform account client — used to create/manage each academia's connected account. */
export function createStripeClient(): Stripe {
  return new Stripe(Deno.env.get("STRIPE_SECRET_KEY")!, {
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
