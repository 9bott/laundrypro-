import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";
import { json, jsonError, preflight } from "../_shared/cors.ts";

const ISSUER_ID = "338800000023107513";
const CLASS_ID = "338800000023107513.laundry-loyalty";

function requireEnv(name: string): string {
  const v = Deno.env.get(name);
  if (!v) throw new Error(`Missing env: ${name}`);
  return v;
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

async function importRsaPrivateKeyFromPkcs8Base64(b64Der: string): Promise<CryptoKey> {
  const clean = b64Der.replace(/\s+/g, "").trim();
  if (!clean) throw new Error("GOOGLE_PRIVATE_KEY_B64 is empty");
  const binaryDer = Uint8Array.from(atob(clean), (c) => c.charCodeAt(0));
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
  privateKeyB64: string,
): Promise<string> {
  const key = await importRsaPrivateKeyFromPkcs8Base64(privateKeyB64);
  const headerPart = base64UrlEncodeJson(header);
  const payloadPart = base64UrlEncodeJson(payload);
  const signingInput = `${headerPart}.${payloadPart}`;
  const sig = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    new TextEncoder().encode(signingInput),
  );
  return `${signingInput}.${base64UrlEncode(new Uint8Array(sig))}`;
}

type Body = { customer_id?: string };

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return preflight();
  if (req.method !== "POST") return jsonError("method_not_allowed", "POST required", 405);

  try {
    const supabaseUrl = requireEnv("SUPABASE_URL");
    const serviceRole = requireEnv("SUPABASE_SERVICE_ROLE_KEY");
    const supabase = createClient(supabaseUrl, serviceRole);

    let body: Body = {};
    try {
      body = (await req.json()) as Body;
    } catch {
      body = {};
    }

    const authHeader = req.headers.get("Authorization");
    let customer: Record<string, unknown> | null = null;

    if (authHeader?.startsWith("Bearer ")) {
      const token = authHeader.replace(/^Bearer\s+/i, "");
      const { data: { user }, error: authError } = await supabase.auth.getUser(token);
      if (!authError && user) {
        const { data, error } = await supabase
          .from("customers")
          .select("*")
          .eq("auth_user_id", user.id)
          .maybeSingle();
        if (!error && data) customer = data as Record<string, unknown>;
      }
    }

    if (!customer) {
      const cid = body.customer_id;
      if (typeof cid === "string" && cid.trim()) {
        const { data, error } = await supabase
          .from("customers")
          .select("*")
          .eq("id", cid.trim())
          .maybeSingle();
        if (!error && data) customer = data as Record<string, unknown>;
      }
    }

    if (!customer) return jsonError("not_found", "Customer not found", 404);

    const now = Math.floor(Date.now() / 1000);
    const cashback = Number(customer.cashback_balance ?? 0).toFixed(2);

    const loyaltyObject = {
      id: `${ISSUER_ID}.pnt${Date.now()}`,
      classId: CLASS_ID,
      state: "ACTIVE",
      accountId: customer.phone,
      accountName: customer.name,
      loyaltyPoints: {
        balance: { string: cashback },
        label: "كاش باك (ريال)",
      },
      barcode: {
        type: "QR_CODE",
        value: customer.id,
        alternateText: customer.phone,
      },
    };

    const jwtPayload: Record<string, unknown> = {
      iss: requireEnv("GOOGLE_SERVICE_ACCOUNT_EMAIL"),
      aud: "google",
      typ: "savetowallet",
      iat: now,
      exp: now + 3600,
      origins: ["https://pay.google.com"],
      payload: {
        loyaltyObjects: [loyaltyObject],
      },
    };

    const privateKeyB64 = requireEnv("GOOGLE_PRIVATE_KEY_B64");
    const jwt = await signRs256({ alg: "RS256", typ: "JWT" }, jwtPayload, privateKeyB64);

    return json({
      success: true,
      wallet_url: `https://pay.google.com/gp/v/save/${jwt}`,
    });
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    return json({ success: false, error: msg }, 400);
  }
});

