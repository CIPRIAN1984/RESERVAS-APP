// RETIRADA. El cobro automático mensual con tarjeta se hace ahora con
// `stripe-checkout-tarifa` (tarifas mensuales → suscripción de Stripe). Esta
// función antigua se deja respondiendo «no disponible» para que, si alguien la
// llama, no toque Stripe ni la base de datos.
import { jsonResponse } from "../_shared/utils.ts";

Deno.serve(() =>
  jsonResponse(
    { error: "Paga tu cuota desde Tarifas." },
    410,
  )
);
