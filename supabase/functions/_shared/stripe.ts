import Stripe from "npm:stripe@17";

/** Platform account client — used to create/manage each academia's connected account. */
export function createStripeClient(): Stripe {
  return new Stripe(Deno.env.get("STRIPE_SECRET_KEY")!, {
    apiVersion: "2024-06-20",
    httpClient: Stripe.createFetchHttpClient(),
  });
}

/** Maps an Account's onboarding fields to our `academias.stripe_onboarding_status` enum. */
export function onboardingStatusFor(account: Stripe.Account): "not_started" | "pending" | "complete" {
  if (!account.details_submitted) return "pending";
  return account.charges_enabled ? "complete" : "pending";
}
