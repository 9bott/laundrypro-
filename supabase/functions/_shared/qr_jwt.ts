import {
  create,
  getNumericDate,
  verify,
} from "https://deno.land/x/djwt@v2.9/mod.ts";

type QrPayload = {
  customer_id: string;
  iat: number;
  exp: number;
};

async function hmacKey(secret: string): Promise<CryptoKey> {
  return await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign", "verify"],
  );
}

export async function signQrToken(customerId: string): Promise<{
  token: string;
  expiresAt: Date;
}> {
  const secret = Deno.env.get("SUPABASE_JWT_SECRET");
  if (!secret) throw new Error("SUPABASE_JWT_SECRET not configured");

  const key = await hmacKey(secret);
  const expMs = Date.now() + 60_000;
  const exp = getNumericDate(new Date(expMs));
  const iat = getNumericDate(new Date());

  const token = await create(
    { alg: "HS256", typ: "JWT" },
    { customer_id: customerId, iat, exp } as Record<string, unknown>,
    key,
  );

  return { token, expiresAt: new Date(expMs) };
}

export async function verifyQrToken(
  token: string,
): Promise<{ ok: true; customerId: string } | { ok: false; code: string }> {
  const secret = Deno.env.get("SUPABASE_JWT_SECRET");
  if (!secret) return { ok: false, code: "qr_secret_missing" };

  try {
    const key = await hmacKey(secret);
    const payload = await verify(token, key) as QrPayload;
    if (!payload?.customer_id) {
      return { ok: false, code: "qr_invalid_payload" };
    }
    const now = Math.floor(Date.now() / 1000);
    if (payload.exp != null && payload.exp < now) {
      return { ok: false, code: "qr_expired" };
    }
    return { ok: true, customerId: payload.customer_id };
  } catch {
    return { ok: false, code: "qr_invalid_signature" };
  }
}
