import { json, jsonError, preflight } from "../_shared/cors.ts";
import { serviceClient } from "../_shared/supabase.ts";
import { requireCustomerId } from "../_shared/auth.ts";
import {
  passkitApiAndPubHosts,
  passkitEnrolMember,
  passkitGetMemberByExternalId,
} from "../_shared/passkit_client.ts";

const DEFAULT_PROGRAM_ID = "70ageTTsrtgK7JPUfvx5A8";

const ENROL_PATHS = [
  "/members/member",
];

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return preflight();

  const supabase = serviceClient();
  const gate = await requireCustomerId(
    supabase,
    req.headers.get("Authorization"),
  );
  if (!gate.ok) return jsonError("unauthorized", gate.message, gate.status);

  const programId = (Deno.env.get("PASSKIT_PROGRAM_ID") ?? DEFAULT_PROGRAM_ID)
    .trim();
  const tierId = (Deno.env.get("PASSKIT_TIER_ID") ?? "").trim();
  const region = (Deno.env.get("PASSKIT_REGION") ?? "pub1").trim();
  const apiKey = (Deno.env.get("PASSKIT_API_KEY") ?? "").trim();

  if (!apiKey) {
    return jsonError(
      "config_error",
      "missing_PASSKIT_API_KEY",
      500,
      { hint: "Supabase Secrets: PASSKIT_API_KEY (long-lived token or API key for JWT)" },
    );
  }
  if (!tierId) {
    return jsonError(
      "config_error",
      "missing_PASSKIT_TIER_ID",
      500,
      {
        hint:
          "Copy tier id from PassKit portal (program tiers). Optional: PASSKIT_PROGRAM_ID, PASSKIT_REGION=pub1|pub2",
      },
    );
  }

  const { apiBase, pubHost } = passkitApiAndPubHosts(region);
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

    const sub = Number(customer.subscription_balance ?? 0);
    const cb = Number(customer.cashback_balance ?? 0);
    const points = Math.max(0, Math.round((sub + cb) * 100) / 100);
    const secondaryPoints = Math.max(0, Math.round(cb * 100) / 100);

    let passId: string | null = null;

    const existing = await passkitGetMemberByExternalId({
      apiBase,
      programId,
      externalId: customerId,
    });
    if (existing.ok) {
      passId = existing.passId;
    } else if (existing.status === 404 ||
               (existing.status === 401 && existing.body?.includes('could not find a user record'))) {
      const displayName = (typeof customer.name === "string" && customer.name.trim())
        ? customer.name.trim()
        : "Customer";
      const phone = (typeof customer.phone === "string" && customer.phone.trim())
        ? customer.phone.trim().replace(/\+/g, "")
        : customerId.replace(/-/g, "").slice(0, 12);
      const payload: Record<string, unknown> = {
        programId,
        tierId,
        externalId: customerId,
        person: {
          forename: displayName.split(" ")[0] || "Customer",
          surname: displayName.split(" ").slice(1).join(" ") || ".",
          displayName,
          emailAddress: `${phone}@point.loyalty`,
          mobileNumber: customer.phone ?? "",
        },
        points,
        secondaryPoints,
      };

      let lastErr = "";
      for (const path of ENROL_PATHS) {
        const en = await passkitEnrolMember({
          apiBase,
          enrolPath: path,
          payload,
        });
        if (en.ok) {
          passId = en.passId;
          break;
        }
        lastErr = `${path}:${en.status}:${en.body}`;
        if (en.status !== 404) {
          console.error("passkit_enrol_failed", lastErr);
        }
      }
      if (!passId) {
        return jsonError(
          "passkit_enrol_failed",
          lastErr.slice(0, 800),
          502,
        );
      }
    } else {
      console.error("passkit_get_external_failed", existing.status, existing.body);
      return jsonError(
        "passkit_lookup_failed",
        existing.body.slice(0, 500),
        existing.status >= 400 ? existing.status : 502,
      );
    }

    const landingUrl = `${pubHost}/${passId}`;
    const applePassUrl = `${landingUrl}.pkpass`;

    return json({
      passId,
      landingUrl,
      applePassUrl,
      programId,
    });
  } catch (e) {
    console.error(e);
    return jsonError(
      "passkit_error",
      e instanceof Error ? e.message : "unknown",
      500,
    );
  }
});
