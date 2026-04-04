import { json, jsonError, preflight } from "../_shared/cors.ts";
import { serviceClient } from "../_shared/supabase.ts";
import { requireCustomerId } from "../_shared/auth.ts";
import { signQrToken } from "../_shared/qr_jwt.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return preflight();

  const supabase = serviceClient();
  const gate = await requireCustomerId(
    supabase,
    req.headers.get("Authorization"),
  );
  if (!gate.ok) {
    return jsonError("unauthorized", gate.message, gate.status);
  }

  try {
    const { token, expiresAt } = await signQrToken(gate.customerId);
    return json({
      qr_token: token,
      expires_at: expiresAt.toISOString(),
    });
  } catch (e) {
    console.error(e);
    return jsonError(
      "config_error",
      e instanceof Error ? e.message : "sign_failed",
      500,
    );
  }
});
