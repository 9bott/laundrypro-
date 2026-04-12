import type { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";

/** صف عميل كما نحتاجه لبطاقة Google Loyalty */
export type CustomerWalletRow = {
  id: string;
  name: string | null;
  phone: string | null;
  cashback_balance: unknown;
  subscription_balance: unknown;
};

function base64urlFromBytes(bytes: Uint8Array): string {
  let s = "";
  for (let i = 0; i < bytes.length; i++) s += String.fromCharCode(bytes[i]);
  return btoa(s).replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_");
}

function base64urlJson(obj: unknown): string {
  return base64urlFromBytes(new TextEncoder().encode(JSON.stringify(obj)));
}

function pemPkcs8ToDerBytes(pem: string): Uint8Array {
  const body = pem
    .replaceAll("\r", "")
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replaceAll("\n", "")
    .trim();
  const raw = atob(body);
  const out = new Uint8Array(raw.length);
  for (let i = 0; i < raw.length; i++) out[i] = raw.charCodeAt(i);
  return out;
}

function wrapBase64Lines(b64: string, lineLen = 64): string {
  const clean = b64.replaceAll("\n", "").replaceAll("\r", "").trim();
  const parts: string[] = [];
  for (let i = 0; i < clean.length; i += lineLen) {
    parts.push(clean.slice(i, i + lineLen));
  }
  return parts.join("\n");
}

export function normalizeSecretValue(value: string): string {
  const v = value.trim();
  const eq = v.indexOf("=");
  if (eq <= 0) return v;
  return v.slice(eq + 1).trim();
}

export function getGooglePrivateKeyPem(): string {
  const pem = (Deno.env.get("GOOGLE_PRIVATE_KEY") ?? "")
    .replaceAll("\\n", "\n")
    .trim();
  if (pem) return pem;

  const b64 = (Deno.env.get("GOOGLE_PRIVATE_KEY_B64") ?? "").trim();
  if (!b64) return "";

  return `-----BEGIN PRIVATE KEY-----\n${wrapBase64Lines(b64)}\n-----END PRIVATE KEY-----`;
}

export type GoogleWalletIssuerConfig = {
  email: string;
  privateKey: string;
  issuerId: string;
  classId: string;
};

/** يعيد null إن لم تُضبط أسرار Google Wallet (تتخطى المزامنة بصمت). */
export function getGoogleWalletIssuerConfig(): GoogleWalletIssuerConfig | null {
  const email = normalizeSecretValue(
    Deno.env.get("GOOGLE_SERVICE_ACCOUNT_EMAIL") ?? "",
  );
  const privateKey = getGooglePrivateKeyPem();
  const issuerId = normalizeSecretValue(Deno.env.get("GOOGLE_ISSUER_ID") ?? "");
  const classId = normalizeSecretValue(
    Deno.env.get("GOOGLE_CLASS_ID") ??
      Deno.env.get("GOOGLE_WALLET_CLASS_ID") ??
      "",
  );
  if (!email || !privateKey || !issuerId || !classId) return null;
  return { email, privateKey, issuerId, classId };
}

async function signJwtRs256(
  header: unknown,
  payload: unknown,
  pem: string,
): Promise<string> {
  const signingInput = `${base64urlJson(header)}.${base64urlJson(payload)}`;
  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemPkcs8ToDerBytes(pem).buffer,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const sig = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    new TextEncoder().encode(signingInput),
  );
  return `${signingInput}.${base64urlFromBytes(new Uint8Array(sig))}`;
}

export async function fetchGoogleAccessToken(params: {
  serviceAccountEmail: string;
  privateKeyPem: string;
  scopes: string[];
}): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const header = { alg: "RS256", typ: "JWT" };
  const payload = {
    iss: params.serviceAccountEmail,
    scope: params.scopes.join(" "),
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  };

  const assertion = await signJwtRs256(header, payload, params.privateKeyPem);
  const body = new URLSearchParams({
    grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
    assertion,
  });

  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "content-type": "application/x-www-form-urlencoded" },
    body,
  });
  const text = await res.text();
  if (!res.ok) throw new Error(`oauth_token_failed:${res.status}:${text}`);
  const parsed = JSON.parse(text) as { access_token?: string };
  const token = parsed.access_token;
  if (!token) throw new Error("oauth_token_missing");
  return token;
}

/**
 * معرّف كائن ولاء ثابت لكل عميل (بدل pnt+timestamp) حتى يمكن PATCH عند تغيّر الرصيد.
 * يزيل شرطات UUID ليتوافق مع أسماء الموارد في Google.
 */
export function loyaltyObjectResourceId(
  issuerId: string,
  customerId: string,
): string {
  return `${issuerId}.${customerId.replace(/-/g, "")}`;
}

function loyaltyObjectBody(
  objectId: string,
  classId: string,
  customer: CustomerWalletRow,
) {
  const totalBalance = (
    Number(customer.cashback_balance ?? 0) +
    Number(customer.subscription_balance ?? 0)
  ).toFixed(2);
  const accountId =
    typeof customer.phone === "string" && customer.phone.trim()
      ? customer.phone.trim()
      : customer.id;

  return {
    id: objectId,
    classId,
    state: "ACTIVE",
    accountId,
    accountName: customer.name ?? "Laundry Customer",
    loyaltyPoints: {
      balance: { string: totalBalance },
      label: "Balance (SAR)",
    },
    barcode: {
      type: "QR_CODE",
      value: customer.id,
      alternateText: accountId,
    },
  };
}

/**
 * ينشئ كائن الولاء أو يحدّثه إن وُجد (409 عند الإنشاء → PATCH).
 * يجب استدعاؤه بعد كل تعديل على أرصدة العميل حتى تنعكس على البطاقة في المحفظة.
 */
export async function upsertGoogleLoyaltyObject(
  accessToken: string,
  classId: string,
  issuerId: string,
  customer: CustomerWalletRow,
): Promise<string> {
  const objectId = loyaltyObjectResourceId(issuerId, customer.id);
  const body = loyaltyObjectBody(objectId, classId, customer);

  const postRes = await fetch(
    "https://walletobjects.googleapis.com/walletobjects/v1/loyaltyObject",
    {
      method: "POST",
      headers: {
        authorization: `Bearer ${accessToken}`,
        "content-type": "application/json",
      },
      body: JSON.stringify(body),
    },
  );

  if (postRes.ok || postRes.status === 201) {
    return objectId;
  }

  if (postRes.status === 409) {
    const updateMask = "loyaltyPoints,accountName,accountId,barcode";
    const patchUrl =
      `https://walletobjects.googleapis.com/walletobjects/v1/loyaltyObject/${objectId}?updateMask=${encodeURIComponent(updateMask)}`;
    const patchRes = await fetch(patchUrl, {
      method: "PATCH",
      headers: {
        authorization: `Bearer ${accessToken}`,
        "content-type": "application/json",
      },
      body: JSON.stringify({
        loyaltyPoints: body.loyaltyPoints,
        accountName: body.accountName,
        accountId: body.accountId,
        barcode: body.barcode,
      }),
    });
    if (!patchRes.ok) {
      const text = await patchRes.text();
      throw new Error(`loyalty_object_patch_failed:${patchRes.status}:${text}`);
    }
    return objectId;
  }

  const text = await postRes.text();
  throw new Error(`loyalty_object_create_failed:${postRes.status}:${text}`);
}

export async function buildGoogleSaveToWalletUrl(params: {
  serviceAccountEmail: string;
  privateKeyPem: string;
  objectId: string;
  classId: string;
  customer: CustomerWalletRow;
}): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const totalBalance = (
    Number(params.customer.cashback_balance ?? 0) +
    Number(params.customer.subscription_balance ?? 0)
  ).toFixed(2);
  const accountId =
    typeof params.customer.phone === "string" &&
      params.customer.phone.trim()
      ? params.customer.phone.trim()
      : params.customer.id;

  const header = { alg: "RS256", typ: "JWT" };
  const payload = {
    iss: params.serviceAccountEmail,
    aud: "google",
    typ: "savetowallet",
    iat: now,
    exp: now + 3600,
    origins: ["https://pay.google.com"],
    payload: {
      loyaltyObjects: [
        {
          id: params.objectId,
          classId: params.classId,
          state: "ACTIVE",
          accountId,
          accountName: params.customer.name ?? "Laundry Customer",
          loyaltyPoints: {
            balance: { string: totalBalance },
            label: "Balance (SAR)",
          },
          barcode: {
            type: "QR_CODE",
            value: params.customer.id,
            alternateText: accountId,
          },
        },
      ],
    },
  };

  const token = await signJwtRs256(
    header,
    payload,
    params.privateKeyPem,
  );
  return `https://pay.google.com/gp/v/save/${token}`;
}

/** مزامنة رصيد/بيانات البطاقة مع Google بعد تحديث `customers` في قاعدة البيانات. */
export async function syncGoogleWalletLoyaltyObject(
  supabase: SupabaseClient,
  customerId: string,
): Promise<void> {
  const cfg = getGoogleWalletIssuerConfig();
  if (!cfg) return;

  const { data: customer, error } = await supabase
    .from("customers")
    .select("id, name, phone, cashback_balance, subscription_balance")
    .eq("id", customerId)
    .maybeSingle();

  if (error || !customer) {
    console.warn(
      "[google_wallet_sync] customer_missing",
      customerId,
      error?.message,
    );
    return;
  }

  const accessToken = await fetchGoogleAccessToken({
    serviceAccountEmail: cfg.email,
    privateKeyPem: cfg.privateKey,
    scopes: ["https://www.googleapis.com/auth/wallet_object.issuer"],
  });

  await upsertGoogleLoyaltyObject(
    accessToken,
    cfg.classId,
    cfg.issuerId,
    customer as CustomerWalletRow,
  );
}

/**
 * لا يرمي للأعلى: فشل Google لا يعطل معاملات النقطة البيع.
 */
export async function trySyncGoogleWalletLoyaltyObject(
  supabase: SupabaseClient,
  customerId: string,
): Promise<void> {
  try {
    await syncGoogleWalletLoyaltyObject(supabase, customerId);
  } catch (e) {
    console.error("[google_wallet_sync]", customerId, e);
  }
}
