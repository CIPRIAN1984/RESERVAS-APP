// RETIRADA el 17/11/2026: la tienda queda fuera de la entrega de prueba (ver
// FREEZE.md). Los permisos de escritura de pedidos están quitados en la base
// de datos; esta función responde «no disponible» y no toca Stripe. Para
// reabrir la tienda hay que recuperar la versión anterior de este fichero.
import { jsonResponse } from "../_shared/utils.ts";

Deno.serve(() =>
  jsonResponse({ error: "La tienda no está disponible en esta versión." }, 410)
);
