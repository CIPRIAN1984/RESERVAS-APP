// RETIRADA (21/11/2026). Dejaba al ALUMNO cancelar su suscripción. Decisión de
// Cipri: solo el Dueño da de baja (`stripe-cancelar-suscripcion`, al darlo de
// baja en la app). Responde «no disponible» sin tocar Stripe ni la base de datos.
import { jsonResponse } from "../_shared/utils.ts";

Deno.serve(() =>
  jsonResponse(
    { error: "Para darte de baja, habla con tu academia." },
    410,
  )
);
