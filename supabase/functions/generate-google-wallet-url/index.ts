import { json, jsonError, preflight } from "../_shared/cors.ts";
import { serviceClient } from "../_shared/supabase.ts";
import { requireCustomerId } from "../_shared/auth.ts";
import {
  buildGoogleSaveToWalletUrl,
  fetchGoogleAccessToken,
  getGoogleWalletIssuerConfig,
  upsertGoogleLoyaltyObject,
} from "../_shared/google_wallet_loyalty.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return preflight();

  const supabase = serviceClient();
  const gate = await requireCustomerId(
    supabase,
    req.headers.get("Authorization"),
  );
  if (!gate.ok) return jsonError("unauthorized", gate.message, gate.status);

  const cfg = getGoogleWalletIssuerConfig();
  if (!cfg) {
    return jsonError(
      "config_error",
      "missing_google_wallet_env",
      500,
      {
        required: [
          "GOOGLE_SERVICE_ACCOUNT_EMAIL",
          "GOOGLE_PRIVATE_KEY (or GOOGLE_PRIVATE_KEY_B64)",
          "GOOGLE_ISSUER_ID",
          "GOOGLE_CLASS_ID (or GOOGLE_WALLET_CLASS_ID)",
        ],
      },
    );
  }

  const customerId = gate.customerId;

  try {
    const { data: customer, error } = await supabase
      .from("customers")
      .select("id, name, phone, cashback_balance, subscription_balance")
      .eq("id", customerId)
      .maybeSingle();

    if (error) {
      console.error(error);
      return jsonError("db_error", "customer_lookup_failed", 500);
    }
    if (!customer) {
      return jsonError("not_found", "customer_not_found", 404);
    }

    const accessToken = await fetchGoogleAccessToken({
      serviceAccountEmail: cfg.email,
      privateKeyPem: cfg.privateKey,
      scopes: ["https://www.googleapis.com/auth/wallet_object.issuer"],
    });

    const objectId = await upsertGoogleLoyaltyObject(
      accessToken,
      cfg.classId,
      cfg.issuerId,
      customer,
    );

    const url = await buildGoogleSaveToWalletUrl({
      serviceAccountEmail: cfg.email,
      privateKeyPem: cfg.privateKey,
      objectId,
      classId: cfg.classId,
      customer,
    });

    return json({ url });
  } catch (e) {
    console.error(e);
    return jsonError(
      "sign_error",
      e instanceof Error ? e.message : "jwt_sign_failed",
      500,
    );
  }
});
