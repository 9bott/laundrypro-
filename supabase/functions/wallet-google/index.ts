import jwt from "npm:jsonwebtoken@9.0.2";
import { supabaseAdmin } from "../_shared/supabase_admin.ts";

type Json =
  | null
  | boolean
  | number
  | string
  | Json[]
  | { [key: string]: Json };

function json(status: number, body: Json) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json; charset=utf-8" },
  });
}

function getEnv(name: string) {
  const v = Deno.env.get(name);
  if (!v) throw new Error(`missing_env:${name}`);
  return v;
}

function normalizePrivateKey(k: string) {
  const trimmed = k.trim();
  if (trimmed.includes("-----BEGIN")) return trimmed.replaceAll("\\n", "\n");
  // allow base64 key contents
  try {
    const raw = atob(trimmed);
    return raw.includes("-----BEGIN") ? raw : trimmed;
  } catch (_) {
    return trimmed.replaceAll("\\n", "\n");
  }
}

Deno.serve(async (req) => {
  try {
    if (req.method !== "GET") return json(405, { error: "method_not_allowed" });

    const url = new URL(req.url);
    const userId = url.searchParams.get("user_id")?.trim() ?? "";
    if (!userId) return json(400, { error: "missing_user_id" });

    const sb = supabaseAdmin();
    const { data: user, error } = await sb
      .from("users")
      .select("id,name,points")
      .eq("id", userId)
      .maybeSingle();

    if (error) throw error;
    if (!user) return json(404, { error: "user_not_found" });

    const serviceEmail = getEnv("GOOGLE_SERVICE_ACCOUNT_EMAIL");
    const privateKey = normalizePrivateKey(getEnv("GOOGLE_PRIVATE_KEY"));
    const issuerId = getEnv("GOOGLE_ISSUER_ID");
    const classId = getEnv("GOOGLE_CLASS_ID");

    const token = jwt.sign(
      {
        loyaltyObjects: [
          {
            id: `${issuerId}.${user.id}`,
            classId,
            accountName: user.name ?? "",
            barcode: { type: "QR_CODE", value: user.id },
          },
        ],
      },
      privateKey,
      {
        algorithm: "RS256",
        issuer: serviceEmail,
        audience: "google",
        header: { typ: "savetowallet" },
      },
    );

    return json(200, { url: `https://pay.google.com/gp/v/save/${token}` });
  } catch (e) {
    return json(500, { error: "internal_error" });
  }
});

