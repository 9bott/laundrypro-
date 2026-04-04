/**
 * Google Wallet — Save to Wallet link via signed JWT (no REST pre-create).
 *
 * Secrets:
 *   supabase secrets set GOOGLE_SERVICE_ACCOUNT_EMAIL="wallet-service@PROJECT.iam.gserviceaccount.com"
 *   supabase secrets set GOOGLE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----"
 *
 * Optional class id override:
 *   supabase secrets set GOOGLE_WALLET_CLASS_ID="BCR2DN5TU2MJZZZL.laundryLoyalty"
 *
 * Deploy:
 *   supabase functions deploy generate-wallet-pass --no-verify-jwt
 */
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";
import { json, preflight } from "../_shared/cors.ts";

const ISSUER_ID = "BCR2DN5TU2MJZZZL";
const CLASS_ID = Deno.env.get("GOOGLE_WALLET_CLASS_ID") ??
  `${ISSUER_ID}.laundrypro-loyalty`;

function requireEnv(name: string): string {
  const v = Deno.env.get(name);
  if (!v) throw new Error(`Missing env: ${name}`);
  return v;
}

function normalizePrivateKey(k: string): string {
  const trimmed = k.trim();
  if (trimmed.includes("-----BEGIN")) return trimmed.replaceAll("\\n", "\n");
  try {
    const raw = atob(trimmed);
    return raw.includes("-----BEGIN") ? raw : trimmed;
  } catch {
    return trimmed.replaceAll("\\n", "\n");
  }
}

function base64UrlEncode(bytes: Uint8Array): string {
  let binary = "";
  for (let i = 0; i < bytes.length; i++) binary += String.fromCharCode(bytes[i]);
  const b64 = btoa(binary);
  return b64.replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/g, "");
}

function base64UrlEncodeJson(obj: unknown): string {
  return base64UrlEncode(new TextEncoder().encode(JSON.stringify(obj)));
}

async function importRsaPrivateKeyFromPkcs8Pem(pem: string): Promise<CryptoKey> {
  const pemContents = pem
    .replace(/-----BEGIN PRIVATE KEY-----/g, "")
    .replace(/-----END PRIVATE KEY-----/g, "")
    .replace(/\s/g, "");
  const binaryDer = Uint8Array.from(
    atob(pemContents),
    (c) => c.charCodeAt(0),
  );
  return await crypto.subtle.importKey(
    "pkcs8",
    binaryDer,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
}

async function signRs256(
  header: Record<string, string>,
  payload: Record<string, unknown>,
  privateKeyPem: string,
): Promise<string> {
  const key = await importRsaPrivateKeyFromPkcs8Pem(privateKeyPem);
  const headerPart = base64UrlEncodeJson(header);
  const payloadPart = base64UrlEncodeJson(payload);
  const signingInput = `${headerPart}.${payloadPart}`;
  const sig = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    new TextEncoder().encode(signingInput),
  );
  const signaturePart = base64UrlEncode(new Uint8Array(sig));
  return `${signingInput}.${signaturePart}`;
}

function buildLoyaltyObject(
  customer: Record<string, unknown>,
  objectId: string,
): Record<string, unknown> {
  const phone = customer.phone;
  const id = customer.id;
  const accountId =
    (typeof phone === "string" && phone.length > 0 ? phone : id) ?? "";
  const alternateText = typeof phone === "string" ? phone : "";
  const name = String(customer.name ?? "");
  const phoneStr = typeof phone === "string" ? phone : "";
  const cb = Number(customer.cashback_balance ?? 0).toFixed(2);
  const sub = Number(customer.subscription_balance ?? 0).toFixed(2);
  const planAr = String(customer.active_plan_name_ar ?? "—");

  return {
    id: objectId,
    classId: CLASS_ID,
    state: "ACTIVE",
    accountId: String(accountId),
    accountName: name,
    loyaltyPoints: {
      balance: {
        string: cb,
      },
      label: "كاش باك (ريال)",
    },
    textModulesData: [
      { id: "cust_name", header: "الاسم", body: name },
      { id: "cust_phone", header: "الجوال", body: phoneStr },
      { id: "cust_cashback", header: "رصيد الكاش باك", body: `${cb} ريال` },
      { id: "cust_subscription", header: "رصيد الاشتراك", body: `${sub} ريال` },
      { id: "cust_plan", header: "الباقة", body: planAr },
    ],
    barcode: {
      type: "QR_CODE",
      value: String(id ?? ""),
      alternateText: alternateText,
    },
  };
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return preflight();

  try {
    const supabaseUrl = requireEnv("SUPABASE_URL");
    const serviceRole = requireEnv("SUPABASE_SERVICE_ROLE_KEY");
    const supabase = createClient(supabaseUrl, serviceRole);

    let parsedBody: Record<string, unknown> = {};
    if (req.method === "POST") {
      try {
        const text = await req.text();
        if (text.trim()) parsedBody = JSON.parse(text) as Record<string, unknown>;
      } catch {
        parsedBody = {};
      }
    }

    const authHeader = req.headers.get("Authorization");
    let customer: Record<string, unknown> | null = null;

    if (authHeader?.startsWith("Bearer ")) {
      const token = authHeader.replace(/^Bearer\s+/i, "");
      const { data: { user }, error: authError } = await supabase.auth.getUser(
        token,
      );
      if (!authError && user) {
        const { data, error: rowErr } = await supabase
          .from("customers")
          .select("*")
          .eq("auth_user_id", user.id)
          .maybeSingle();
        if (!rowErr && data) customer = data as Record<string, unknown>;
      }
    }

    if (!customer) {
      const cid = parsedBody.customer_id;
      if (typeof cid === "string" && cid.length > 0) {
        const { data, error: rowErr } = await supabase
          .from("customers")
          .select("*")
          .eq("id", cid)
          .maybeSingle();
        if (!rowErr && data) customer = data as Record<string, unknown>;
      }
    }

    if (!customer) {
      throw new Error(
        "Customer not found (auth failed and no valid customer_id in body)",
      );
    }

    const objectId = `${ISSUER_ID}.u${Date.now()}`;
    const loyaltyObject = buildLoyaltyObject(customer, objectId);

    const serviceAccountEmail = requireEnv("GOOGLE_SERVICE_ACCOUNT_EMAIL");
    const privateKey = normalizePrivateKey(requireEnv("GOOGLE_PRIVATE_KEY"));

    const iat = Math.floor(Date.now() / 1000);
    const jwtPayload: Record<string, unknown> = {
      iss: serviceAccountEmail,
      aud: "google",
      typ: "savetowallet",
      iat,
      exp: iat + 3600,
      origins: [],
      payload: {
        loyaltyObjects: [loyaltyObject],
      },
    };

    const jwt = await signRs256(
      { alg: "RS256", typ: "savetowallet" },
      jwtPayload,
      privateKey,
    );

    return json({
      success: true,
      wallet_url: `https://pay.google.com/gp/v/save/${jwt}`,
      customer_name: String(customer.name ?? ""),
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    return json({ success: false, error: message }, 400);
  }
});
