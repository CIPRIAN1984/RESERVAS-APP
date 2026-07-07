// Minimal Firebase Cloud Messaging (HTTP v1) client for Deno Edge Functions.
//
// Auth: FCM v1 needs an OAuth2 access token minted from a Google service
// account. We build and RS256-sign a JWT with the account's private key
// (via SubtleCrypto) and exchange it at Google's token endpoint. The service
// account JSON is provided whole in the FCM_SERVICE_ACCOUNT secret.

interface ServiceAccount {
  client_email: string;
  private_key: string;
  project_id: string;
}

function pemToArrayBuffer(pem: string): ArrayBuffer {
  const b64 = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\s+/g, "");
  const binary = atob(b64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return bytes.buffer;
}

function base64url(input: string | Uint8Array): string {
  const bytes = typeof input === "string" ? new TextEncoder().encode(input) : input;
  let bin = "";
  for (const b of bytes) bin += String.fromCharCode(b);
  return btoa(bin).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

async function getAccessToken(sa: ServiceAccount): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const header = base64url(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const claims = base64url(JSON.stringify({
    iss: sa.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  }));
  const unsigned = `${header}.${claims}`;

  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemToArrayBuffer(sa.private_key),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const sig = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    new TextEncoder().encode(unsigned),
  );
  const jwt = `${unsigned}.${base64url(new Uint8Array(sig))}`;

  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });
  if (!res.ok) throw new Error(`Token FCM: ${res.status} ${await res.text()}`);
  return (await res.json()).access_token as string;
}

export interface FcmClient {
  projectId: string;
  accessToken: string;
}

/** Builds an authenticated client, or null when FCM isn't configured. */
export async function createFcmClient(): Promise<FcmClient | null> {
  const raw = Deno.env.get("FCM_SERVICE_ACCOUNT");
  if (!raw) return null;
  const sa = JSON.parse(raw) as ServiceAccount;
  return { projectId: sa.project_id, accessToken: await getAccessToken(sa) };
}

/**
 * Sends one notification to one token. Returns "ok", or "invalid" when FCM
 * reports the token is stale/unregistered (caller should delete it), or
 * "error" for a transient failure (caller may retry later).
 */
export async function sendToToken(
  client: FcmClient,
  token: string,
  title: string,
  body: string,
  data: Record<string, string>,
): Promise<"ok" | "invalid" | "error"> {
  const res = await fetch(
    `https://fcm.googleapis.com/v1/projects/${client.projectId}/messages:send`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${client.accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ message: { token, notification: { title, body }, data } }),
    },
  );
  if (res.ok) return "ok";
  if (res.status === 404 || res.status === 400) return "invalid";
  return "error";
}
