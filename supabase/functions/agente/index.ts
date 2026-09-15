// La puerta de solo lectura para el agente personal del Dueño.
//
// Habla dos idiomas sobre la misma URL:
//
//   · **MCP** (JSON-RPC 2.0 por POST) — es lo que entienden ChatGPT y Claude
//     cuando les añades un conector. Implementa `initialize`, `tools/list` y
//     `tools/call`, que es el mínimo que necesitan.
//   · **GET sencillo** (`?consulta=resumen&desde=…`) — para probar con curl
//     y para cualquier programa que no hable MCP.
//
// Por aquí NO se puede escribir. No hay ni una ruta que modifique nada: las
// cuatro consultas son funciones `stable` de PostgreSQL y el único `insert`
// que hace este fichero es el del propio registro de accesos.
//
// La autenticación es la clave `itc_…` que el Dueño genera desde la app, en
// la cabecera `Authorization: Bearer`. Se guarda troceada, así que aquí se
// trocea la que llega y se busca por huella.

import { createAdminClient, jsonResponse, logEvent } from "../_shared/utils.ts";

const FN = "agente";

// El agente pide por la URL; el navegador de ChatGPT hace primero un
// OPTIONS. Sin esto, el conector no llega ni a autenticarse.
const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, content-type, mcp-session-id, mcp-protocol-version",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
  "Access-Control-Expose-Headers": "mcp-session-id",
};

function conCors(res: Response): Response {
  const headers = new Headers(res.headers);
  for (const [k, v] of Object.entries(CORS)) headers.set(k, v);
  return new Response(res.body, { status: res.status, headers });
}

async function huella(clave: string): Promise<string> {
  const bytes = new TextEncoder().encode(clave);
  const hash = await crypto.subtle.digest("SHA-256", bytes);
  return Array.from(new Uint8Array(hash))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

interface Clave {
  id: string;
  academia_id: string;
  incluye_contacto: boolean;
}

/** Resuelve la clave presentada, o `null` si no vale. */
async function claveDe(req: Request): Promise<Clave | null> {
  const cabecera = req.headers.get("Authorization") ?? "";
  const presentada = cabecera.replace(/^Bearer\s+/i, "").trim();
  if (!presentada.startsWith("itc_")) return null;

  const admin = createAdminClient();
  const { data, error } = await admin
    .from("claves_agente")
    .select("id, academia_id, incluye_contacto")
    .eq("clave_hash", await huella(presentada))
    .is("revocada_at", null)
    .maybeSingle();

  if (error) {
    logEvent("error", FN, "No se ha podido comprobar la clave", { error: error.message });
    return null;
  }
  return data as Clave | null;
}

/** Deja constancia de lo que ha leído el agente, para que el Dueño lo vea. */
async function registrar(
  clave: Clave,
  consulta: string,
  parametros: Record<string, unknown>,
  filas: number,
): Promise<void> {
  const admin = createAdminClient();
  // El registro no debe tumbar la respuesta: si falla, se anota y se sigue.
  const { error } = await admin.from("consultas_agente").insert({
    clave_id: clave.id,
    academia_id: clave.academia_id,
    consulta,
    parametros,
    filas,
  });
  if (error) logEvent("warn", FN, "No se ha podido registrar la consulta", { error: error.message });
  await admin.from("claves_agente").update({ ultimo_uso_at: new Date().toISOString() }).eq("id", clave.id);
}

function hoyMas(dias: number): string {
  const d = new Date();
  d.setUTCDate(d.getUTCDate() + dias);
  return d.toISOString().slice(0, 10);
}

function fecha(valor: unknown, porDefecto: string): string {
  return typeof valor === "string" && /^\d{4}-\d{2}-\d{2}$/.test(valor) ? valor : porDefecto;
}

/** Cuántas cosas ha devuelto una respuesta, solo para el registro. */
function cuantas(datos: unknown): number {
  if (Array.isArray(datos)) return datos.length;
  if (datos && typeof datos === "object") return Object.keys(datos as object).length;
  return 0;
}

const HERRAMIENTAS = [
  {
    name: "resumen",
    description:
      "Números de la academia en un periodo: alumnos activos y de baja, altas y bajas, " +
      "clases programadas, plazas, reservas, ocupación media y cuántas cuotas están al día. " +
      "Sin nombres propios.",
    inputSchema: {
      type: "object",
      properties: {
        desde: { type: "string", description: "Fecha inicial, AAAA-MM-DD. Por defecto, hace 30 días." },
        hasta: { type: "string", description: "Fecha final, AAAA-MM-DD. Por defecto, hoy." },
      },
    },
  },
  {
    name: "avisos",
    description:
      "A quién hay que prestar atención, con nombre y apellidos: quién no tiene la cuota al día, " +
      "quién lleva semanas sin aparecer por el tatami y quién ya cumple los entrenos para el " +
      "siguiente cinturón.",
    inputSchema: {
      type: "object",
      properties: {
        dias_sin_venir: {
          type: "integer",
          description: "A partir de cuántos días sin entrenar se considera ausente. Por defecto 21.",
        },
      },
    },
  },
  {
    name: "horario",
    description:
      "Las clases de un rango de fechas: título, hora, profesor, aforo, cuántos hay apuntados, " +
      "cuántos en lista de espera y cuántas plazas quedan libres.",
    inputSchema: {
      type: "object",
      properties: {
        desde: { type: "string", description: "Fecha inicial, AAAA-MM-DD. Por defecto, hoy." },
        hasta: { type: "string", description: "Fecha final, AAAA-MM-DD. Por defecto, dentro de 7 días." },
      },
    },
  },
  {
    name: "alumnos",
    description:
      "La lista de alumnos: nombre, cinturón, si es menor, fecha de alta y si tiene la cuota al día. " +
      "El correo solo aparece si esta clave lo tiene autorizado.",
    inputSchema: {
      type: "object",
      properties: {
        incluir_bajas: {
          type: "boolean",
          description: "Incluir también a quien ya no entrena. Por defecto, no.",
        },
      },
    },
  },
];

async function ejecutar(
  clave: Clave,
  herramienta: string,
  args: Record<string, unknown>,
): Promise<{ datos: unknown } | { error: string }> {
  const admin = createAdminClient();
  let datos: unknown;

  switch (herramienta) {
    case "resumen": {
      const desde = fecha(args.desde, hoyMas(-30));
      const hasta = fecha(args.hasta, hoyMas(0));
      const { data, error } = await admin.rpc("agente_resumen", {
        p_academia_id: clave.academia_id,
        p_desde: desde,
        p_hasta: hasta,
      });
      if (error) return { error: error.message };
      datos = data;
      await registrar(clave, "resumen", { desde, hasta }, cuantas(data));
      break;
    }
    case "avisos": {
      const dias = Number.isInteger(args.dias_sin_venir) ? (args.dias_sin_venir as number) : 21;
      const { data, error } = await admin.rpc("agente_avisos", {
        p_academia_id: clave.academia_id,
        p_dias_sin_venir: dias,
      });
      if (error) return { error: error.message };
      datos = data;
      await registrar(clave, "avisos", { dias_sin_venir: dias }, cuantas(data));
      break;
    }
    case "horario": {
      const desde = fecha(args.desde, hoyMas(0));
      const hasta = fecha(args.hasta, hoyMas(7));
      const { data, error } = await admin.rpc("agente_horario", {
        p_academia_id: clave.academia_id,
        p_desde: desde,
        p_hasta: hasta,
      });
      if (error) return { error: error.message };
      datos = data;
      await registrar(clave, "horario", { desde, hasta }, cuantas(data));
      break;
    }
    case "alumnos": {
      const incluirBajas = args.incluir_bajas === true;
      const { data, error } = await admin.rpc("agente_alumnos", {
        p_academia_id: clave.academia_id,
        // El interruptor lo manda la clave, NO lo que pida el agente: si
        // viniera del argumento, bastaría con pedirlo para saltárselo.
        p_incluir_contacto: clave.incluye_contacto,
        p_incluir_bajas: incluirBajas,
      });
      if (error) return { error: error.message };
      datos = data;
      await registrar(clave, "alumnos", { incluir_bajas: incluirBajas }, cuantas(data));
      break;
    }
    default:
      return { error: `No existe ninguna consulta llamada «${herramienta}».` };
  }

  return { datos };
}

// --- MCP (JSON-RPC 2.0) ----------------------------------------------------

function respuestaRpc(id: unknown, resultado: unknown): Response {
  return jsonResponse({ jsonrpc: "2.0", id, result: resultado });
}

function errorRpc(id: unknown, codigo: number, mensaje: string): Response {
  return jsonResponse({ jsonrpc: "2.0", id, error: { code: codigo, message: mensaje } });
}

async function atenderMcp(req: Request, clave: Clave): Promise<Response> {
  let cuerpo: { jsonrpc?: string; id?: unknown; method?: string; params?: Record<string, unknown> };
  try {
    cuerpo = await req.json();
  } catch {
    return errorRpc(null, -32700, "El cuerpo de la petición no es JSON válido.");
  }

  const { id = null, method, params = {} } = cuerpo;

  switch (method) {
    case "initialize":
      return respuestaRpc(id, {
        protocolVersion: "2024-11-05",
        capabilities: { tools: {} },
        serverInfo: { name: "itaca-reservas", version: "1.0.0" },
      });

    // Avisos sin respuesta: el protocolo exige no contestar con un resultado.
    case "notifications/initialized":
    case "notifications/cancelled":
      return new Response(null, { status: 202 });

    case "ping":
      return respuestaRpc(id, {});

    case "tools/list":
      return respuestaRpc(id, { tools: HERRAMIENTAS });

    case "tools/call": {
      const nombre = String(params.name ?? "");
      const args = (params.arguments ?? {}) as Record<string, unknown>;
      const salida = await ejecutar(clave, nombre, args);

      if ("error" in salida) {
        return respuestaRpc(id, {
          content: [{ type: "text", text: salida.error }],
          isError: true,
        });
      }
      return respuestaRpc(id, {
        content: [{ type: "text", text: JSON.stringify(salida.datos, null, 2) }],
      });
    }

    default:
      return errorRpc(id, -32601, `Método no soportado: ${method}`);
  }
}

// --- Entrada ---------------------------------------------------------------

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return conCors(new Response(null, { status: 204 }));
  }

  try {
    const clave = await claveDe(req);
    if (!clave) {
      // Sin pistas sobre por qué: si la clave es mala, es mala.
      return conCors(jsonResponse({ error: "Clave no válida." }, 401));
    }

    if (req.method === "POST") {
      return conCors(await atenderMcp(req, clave));
    }

    if (req.method === "GET") {
      const url = new URL(req.url);
      const consulta = url.searchParams.get("consulta");
      if (!consulta) {
        return conCors(jsonResponse({
          academia: clave.academia_id,
          incluye_contacto: clave.incluye_contacto,
          consultas: HERRAMIENTAS.map((h) => ({ nombre: h.name, para: h.description })),
        }));
      }
      const args = Object.fromEntries(url.searchParams.entries());
      if (args.dias_sin_venir) args.dias_sin_venir = Number(args.dias_sin_venir) as never;
      if (args.incluir_bajas) args.incluir_bajas = (args.incluir_bajas === "true") as never;

      const salida = await ejecutar(clave, consulta, args);
      if ("error" in salida) return conCors(jsonResponse({ error: salida.error }, 400));
      return conCors(jsonResponse(salida.datos));
    }

    return conCors(jsonResponse({ error: "Método no permitido." }, 405));
  } catch (error) {
    logEvent("error", FN, "Error atendiendo al agente", {
      error: error instanceof Error ? error.message : String(error),
    });
    return conCors(jsonResponse({ error: "No se ha podido atender la consulta." }, 500));
  }
});
