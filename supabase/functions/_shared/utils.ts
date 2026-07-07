import { createClient, SupabaseClient } from "npm:@supabase/supabase-js@2";

export function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

/**
 * Structured JSON logging for Edge Functions. Emitting one JSON object per log
 * line (instead of interpolated strings) makes the Supabase/Deno logs
 * queryable and easy to forward to an aggregator later. Never log secrets or
 * full request bodies — pass only the fields you need for diagnosis.
 */
export function logEvent(
  level: "info" | "warn" | "error",
  fn: string,
  message: string,
  context: Record<string, unknown> = {},
): void {
  const line = JSON.stringify({
    level,
    fn,
    message,
    ts: new Date().toISOString(),
    ...context,
  });
  if (level === "error") console.error(line);
  else if (level === "warn") console.warn(line);
  else console.log(line);
}

/** Bypasses RLS — only ever used for writes/reads that the caller isn't allowed to do directly. */
export function createAdminClient(): SupabaseClient {
  return createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );
}

/** Scoped to the caller's own JWT — every query through it is RLS-checked as that user. */
export function createUserClient(authHeader: string): SupabaseClient {
  return createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    { global: { headers: { Authorization: authHeader } } },
  );
}

export interface CallerProfile {
  userId: string;
  email: string | null;
  rol: string;
  academiaId: string | null;
}

/** Verifies the request's JWT and returns the caller's own profile, or null if unauthenticated/not found. */
export async function getCallerProfile(req: Request): Promise<CallerProfile | null> {
  const authHeader = req.headers.get("Authorization");
  if (!authHeader) return null;

  const supabaseUser = createUserClient(authHeader);
  const { data: userData } = await supabaseUser.auth.getUser();
  if (!userData?.user) return null;

  const { data: profile } = await supabaseUser
    .from("profiles")
    .select("rol, academia_id")
    .eq("id", userData.user.id)
    .single();
  if (!profile) return null;

  return {
    userId: userData.user.id,
    email: userData.user.email ?? null,
    rol: profile.rol as string,
    academiaId: profile.academia_id as string | null,
  };
}
