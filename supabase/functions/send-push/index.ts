// Drains public.notificaciones_outbox and delivers each pending notification
// via FCM. Meant to be invoked on a schedule (pg_cron + pg_net, or an external
// cron hitting this endpoint) — not by end users. Deployed with
// --no-verify-jwt and protected by the CRON_SECRET header check below.
import { createAdminClient, jsonResponse, logEvent } from "../_shared/utils.ts";
import { createFcmClient, sendToToken } from "../_shared/fcm.ts";

const BATCH = 100;

Deno.serve(async (req) => {
  // Only the scheduler may call this. CRON_SECRET is a shared secret passed in
  // the X-Cron-Secret header.
  const expected = Deno.env.get("CRON_SECRET");
  if (!expected) {
    logEvent("error", "send-push", "CRON_SECRET ausente; ejecución bloqueada");
    return jsonResponse({ error: "Servicio no configurado." }, 503);
  }
  if (req.headers.get("X-Cron-Secret") !== expected) {
    return jsonResponse({ error: "No autorizado." }, 401);
  }

  const fcm = await createFcmClient();
  if (!fcm) {
    logEvent(
      "warn",
      "send-push",
      "FCM sin configurar (FCM_SERVICE_ACCOUNT ausente)",
    );
    return jsonResponse({ error: "FCM no configurado." }, 503);
  }

  const admin = createAdminClient();
  const { data: pendientes, error } = await admin
    .from("notificaciones_outbox")
    .select("id, user_id, titulo, cuerpo, data")
    .eq("enviada", false)
    .order("created_at", { ascending: true })
    .limit(BATCH);

  if (error) {
    logEvent("error", "send-push", "No se pudo leer la outbox", {
      error: error.message,
    });
    return jsonResponse({ error: "Error leyendo la outbox." }, 500);
  }

  let enviadas = 0;
  let tokensInvalidos = 0;
  let reintentos = 0;

  for (const n of pendientes ?? []) {
    const { data: tokens } = await admin
      .from("device_tokens")
      .select("token")
      .eq("user_id", n.user_id);

    const dataStr: Record<string, string> = {};
    for (
      const [k, v] of Object.entries((n.data ?? {}) as Record<string, unknown>)
    ) {
      dataStr[k] = String(v);
    }

    let retryRequired = false;
    for (const { token } of tokens ?? []) {
      const result = await sendToToken(fcm, token, n.titulo, n.cuerpo, dataStr);
      if (result === "invalid") {
        // Token muerto: se borra para no reintentar indefinidamente.
        await admin.from("device_tokens").delete().eq("token", token);
        tokensInvalidos++;
      } else if (result === "error") {
        retryRequired = true;
      }
    }

    if (retryRequired) {
      reintentos++;
      continue;
    }

    await admin
      .from("notificaciones_outbox")
      .update({ enviada: true, enviada_at: new Date().toISOString() })
      .eq("id", n.id);
    enviadas++;
  }

  logEvent("info", "send-push", "Lote procesado", {
    enviadas,
    tokensInvalidos,
    reintentos,
  });
  return jsonResponse({
    enviadas,
    tokens_invalidos: tokensInvalidos,
    reintentos,
  });
});
