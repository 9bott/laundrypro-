import {
  create,
  decode,
  getNumericDate,
  verify,
} from "https://deno.land/x/djwt@v2.9/mod.ts";

type QrPayload = {
  customer_id: string;
  iat: number;
  exp: number;
};

/** باركود Google Wallet (loyaltyObject.barcode.value) يضع `customers.id` كـ UUID وليس JWT. */
export function tryParsePlainCustomerId(raw: string): string | null {
  let s = raw.trim().replace(/^\{+|\}+$/g, "");
  s = s.replace(/[\u2010\u2011\u2012\u2013\u2014]/g, "-");
  const lower = s.toLowerCase();
  if (lower.startsWith("urn:uuid:")) s = s.slice("urn:uuid:".length).trim();
  if (!s || s.includes(".")) return null;
  if (
    /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(s)
  ) {
    return s;
  }
  return null;
}

/**
 * سر موقّع/متحقق رمز الـ QR (HS256). لوحة Supabase أحياناً تمنع الاسم المحجوز
 * `SUPABASE_JWT_SECRET` — ندعم بدائل بأسماء خاصة بالمشروع.
 */
function qrJwtSharedSecret(): string | undefined {
  // الأسماء اليدوية أولاً — Supabase قد يحقن SUPABASE_JWT_SECRET تلقائياً بقيمة لا تطابق سرك المخزَّن في SUPABASE1_*.
  const candidates = [
    Deno.env.get("QR_JWT_SECRET"),
    Deno.env.get("SUPABASE1_JWT_SECRET"),
    Deno.env.get("SUPABASE_JWT_SECRET"),
  ];
  for (const c of candidates) {
    const t = c?.trim();
    if (t) return t;
  }
  return undefined;
}

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
  const secret = qrJwtSharedSecret();
  if (!secret) {
    throw new Error(
      "QR JWT secret not configured (set SUPABASE_JWT_SECRET or QR_JWT_SECRET or SUPABASE1_JWT_SECRET)",
    );
  }

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

/** انتهاء الصلاحية يُفحص داخل djwt قبل التحقق من التوقيع؛ كان يُلتقط كـ qr_invalid. */
const VERIFY_OPTS = { expLeeway: 30, nbfLeeway: 30 };

export async function verifyQrToken(
  token: string,
): Promise<{ ok: true; customerId: string } | { ok: false; code: string }> {
  const secret = qrJwtSharedSecret();
  if (!secret) return { ok: false, code: "qr_secret_missing" };

  try {
    decode(token);
  } catch {
    return { ok: false, code: "qr_malformed" };
  }

  try {
    const key = await hmacKey(secret);
    const payload = await verify(token, key, VERIFY_OPTS) as QrPayload;
    if (!payload?.customer_id || typeof payload.customer_id !== "string") {
      return { ok: false, code: "qr_invalid_payload" };
    }
    return { ok: true, customerId: payload.customer_id };
  } catch (e) {
    if (e instanceof RangeError) {
      const m = e.message ?? "";
      if (m.includes("expired") || m.includes("too early")) {
        return { ok: false, code: "qr_expired" };
      }
    }
    const msg = e instanceof Error ? e.message : String(e);
    if (/expired|too early/i.test(msg)) {
      return { ok: false, code: "qr_expired" };
    }
    return { ok: false, code: "qr_invalid_signature" };
  }
}
