// Called when a Dueño taps "Conectar con Stripe". Creates the academia's
// Stripe Connect (Standard) account if it doesn't exist yet, and always
// returns a fresh Account Link URL to open in an external browser.
import { createAdminClient, getCallerProfile, jsonResponse } from "../_shared/utils.ts";
import { createStripeClient } from "../_shared/stripe.ts";

const RETURN_URL = "https://web-henna-seven-16.vercel.app";

Deno.serve(async (req) => {
  try {
    const caller = await getCallerProfile(req);
    if (!caller) return jsonResponse({ error: "No autorizado." }, 401);
    if (caller.rol !== "dueño" || !caller.academiaId) {
      return jsonResponse({ error: "Solo el Dueño de una academia puede conectar Stripe." }, 403);
    }

    const admin = createAdminClient();
    const { data: academia, error: academiaError } = await admin
      .from("academias")
      .select("id, nombre, email_contacto, stripe_account_id")
      .eq("id", caller.academiaId)
      .single();
    if (academiaError || !academia) {
      return jsonResponse({ error: "Academia no encontrada." }, 404);
    }

    const stripe = createStripeClient();
    let accountId = academia.stripe_account_id as string | null;

    if (!accountId) {
      const account = await stripe.accounts.create({
        type: "standard",
        country: "ES",
        email: academia.email_contacto || undefined,
        business_profile: academia.nombre ? { name: academia.nombre } : undefined,
      });
      accountId = account.id;

      await admin
        .from("academias")
        .update({ stripe_account_id: accountId, stripe_onboarding_status: "pending" })
        .eq("id", academia.id);
    }

    const accountLink = await stripe.accountLinks.create({
      account: accountId,
      refresh_url: RETURN_URL,
      return_url: RETURN_URL,
      type: "account_onboarding",
    });

    return jsonResponse({ url: accountLink.url });
  } catch (error) {
    console.error("stripe-connect-onboarding error:", error);
    return jsonResponse({ error: "No se ha podido iniciar la conexión con Stripe." }, 500);
  }
});
