// Lets the Dueño get an immediate status refresh after returning from Stripe's
// hosted onboarding, instead of waiting on webhook delivery latency.
import { createAdminClient, getCallerProfile, jsonResponse } from "../_shared/utils.ts";
import { createStripeClient, onboardingStatusFor } from "../_shared/stripe.ts";

Deno.serve(async (req) => {
  try {
    const caller = await getCallerProfile(req);
    if (!caller || !caller.academiaId) {
      return jsonResponse({ error: "No autorizado." }, 401);
    }

    const admin = createAdminClient();
    const { data: academia, error: academiaError } = await admin
      .from("academias")
      .select("id, stripe_account_id, stripe_onboarding_status, stripe_charges_enabled")
      .eq("id", caller.academiaId)
      .single();
    if (academiaError || !academia) {
      return jsonResponse({ error: "Academia no encontrada." }, 404);
    }

    if (!academia.stripe_account_id) {
      return jsonResponse({ stripe_onboarding_status: "not_started", stripe_charges_enabled: false });
    }

    const stripe = createStripeClient();
    const account = await stripe.accounts.retrieve(academia.stripe_account_id);
    const status = onboardingStatusFor(account);
    const chargesEnabled = account.charges_enabled ?? false;

    await admin
      .from("academias")
      .update({ stripe_onboarding_status: status, stripe_charges_enabled: chargesEnabled })
      .eq("id", academia.id);

    return jsonResponse({ stripe_onboarding_status: status, stripe_charges_enabled: chargesEnabled });
  } catch (error) {
    console.error("stripe-connect-status error:", error);
    return jsonResponse({ error: "No se ha podido comprobar el estado." }, 500);
  }
});
