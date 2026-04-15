/**
 * PassKit (passkit.io) REST
 * - Long-lived token: PASSKIT_API_KEY only → Authorization: Bearer <key>
 * - JWT: PASSKIT_API_KEY + PASSKIT_API_SECRET → HS256 JWT with { uid, exp, iat }
 */

function base64urlFromBytes(bytes: Uint8Array): string {
  let s = "";
  for (let i = 0; i < bytes.length; i++) s += String.fromCharCode(bytes[i]);
  return btoa(s).replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_");
}

function base64urlJson(obj: unknown): string {
  return base64urlFromBytes(new TextEncoder().encode(JSON.stringify(obj)));
}

async function signPasskitJwt(apiKey: string, apiSecret: string): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const header = { alg: "HS256", typ: "JWT" };
  const payload = {
    uid: apiKey,
    exp: now + 3600,
    iat: now,
  };
  const signingInput = `${base64urlJson(header)}.${base64urlJson(payload)}`;
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(apiSecret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const sig = await crypto.subtle.sign(
    "HMAC",
    key,
    new TextEncoder().encode(signingInput),
  );
  return `${signingInput}.${base64urlFromBytes(new Uint8Array(sig))}`;
}

export function passkitApiAndPubHosts(region: string): { apiBase: string; pubHost: string } {
  const r = region === "pub2" || region === "us" || region === "USA"
    ? "pub2"
    : "pub1";
  return {
    apiBase: `https://api.${r}.passkit.io`,
    pubHost: `https://${r}.pskt.io`,
  };
}

export async function getPasskitAuth(): Promise<string | null> {
  const rawKey = (Deno.env.get("PASSKIT_API_KEY") ?? "").trim();
  if (!rawKey) return null;

  const secret = (Deno.env.get("PASSKIT_API_SECRET") ?? "").trim();
  if (secret) {
    const jwt = await signPasskitJwt(rawKey, secret);
    return jwt;
  }

  return `Bearer ${rawKey}`;
}

function readMemberId(obj: Record<string, unknown>): string | null {
  const id = obj.id ??
    (obj.result as Record<string, unknown> | undefined)?.id ??
    (obj.member as Record<string, unknown> | undefined)?.id;
  return typeof id === "string" && id.length > 0 ? id : null;
}

export function extractPassKitMemberId(text: string): string | null {
  const trimmed = text.trim();
  if (!trimmed) return null;
  const lines = trimmed.split("\n").filter((l) => l.trim());
  for (const line of lines) {
    try {
      const id = readMemberId(JSON.parse(line) as Record<string, unknown>);
      if (id) return id;
    } catch {
      // continue
    }
  }
  try {
    return readMemberId(JSON.parse(trimmed) as Record<string, unknown>);
  } catch {
    /* ignore */
  }
  return null;
}

export async function passkitGetMemberByExternalId(params: {
  apiBase: string;
  programId: string;
  externalId: string;
}): Promise<{ ok: true; passId: string } | { ok: false; status: number; body: string }> {
  const auth = await getPasskitAuth();
  if (!auth) return { ok: false, status: 500, body: "missing_passkit_key" };

  const path =
    `${params.apiBase}/members/member/externalId/${
      encodeURIComponent(params.programId)
    }/${encodeURIComponent(params.externalId)}`;
  const res = await fetch(path, {
    method: "GET",
    headers: { authorization: auth },
  });
  const body = await res.text();
  if (!res.ok) {
    return { ok: false, status: res.status, body };
  }
  const passId = extractPassKitMemberId(body);
  if (!passId) {
    return { ok: false, status: 502, body: "pass_id_parse_failed" };
  }
  return { ok: true, passId };
}

export async function passkitEnrolMember(params: {
  apiBase: string;
  enrolPath: string;
  payload: Record<string, unknown>;
}): Promise<{ ok: true; passId: string } | { ok: false; status: number; body: string }> {
  const body = JSON.stringify(params.payload);
  const auth = await getPasskitAuth();
  if (!auth) return { ok: false, status: 500, body: "missing_passkit_key" };

  const res = await fetch(`${params.apiBase}${params.enrolPath}`, {
    method: "POST",
    headers: {
      authorization: auth,
      "content-type": "application/json",
    },
    body,
  });
  const text = await res.text();
  if (!res.ok) {
    return { ok: false, status: res.status, body: text };
  }
  const passId = extractPassKitMemberId(text);
  if (!passId) {
    return { ok: false, status: 502, body: `parse_failed:${text.slice(0, 500)}` };
  }
  return { ok: true, passId };
}
