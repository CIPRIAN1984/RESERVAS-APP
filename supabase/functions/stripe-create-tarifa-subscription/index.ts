// RETIRADA el 17/11/2026. Creaba una suscripción recurrente de Stripe para
// cualquier tarifa (y no admitía el día suelto). Cipri no ha acordado cobros
// recurrentes: cada pago con tarjeta es un solo periodo y se hace con
// `stripe-checkout-tarifa`. Se deja la función respondiendo «no disponible»
// para que, si alguien la llama, no toque Stripe ni la base de datos.
import { jsonResponse } from "../_shared/utils.ts";

Deno.serve(() =>
  jsonResponse(
    {
      error:
        "Los cobros recurrentes no están disponibles. Paga tu cuota desde Tarifas.",
    },
    410,
  )
);
