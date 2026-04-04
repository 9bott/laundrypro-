import { json, jsonError, preflight } from "../_shared/cors.ts";
import { serviceClient } from "../_shared/supabase.ts";
import { requireStaff } from "../_shared/auth.ts";
import { verifyQrToken } from "../_shared/qr_jwt.ts";

type Body = { qr_token: string };

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return preflight();

  const supabase = serviceClient();
  const staffGate = await requireStaff(supabase, req.headers.get("Authorization"));
  if (!staffGate.ok) {
    return jsonError("unauthorized", staffGate.message, staffGate.status);
  }

  let body: Body;
  try {
    body = (await req.json()) as Body;
  } catch {
    return jsonError("bad_json", "Invalid JSON body", 400);
  }

  if (!body.qr_token) {
    return jsonError("validation", "qr_token required", 400);
  }

  const verified = await verifyQrToken(body.qr_token);
  if (!verified.ok) {
    return jsonError(
      verified.code === "qr_expired" ? "qr_expired" : "qr_invalid",
      verified.code === "qr_expired"
        ? "QR code expired, ask customer to refresh"
        : "Invalid QR token",
      400,
    );
  }

  const { data: customer, error } = await supabase
    .from("customers")
    .select(
      "id, name, avatar_url, cashback_balance, subscription_balance, tier, visit_count, active_plan_name, active_plan_name_ar",
    )
    .eq("id", verified.customerId)
    .maybeSingle();

  if (error || !customer) {
    return jsonError("not_found", "customer_not_found", 404);
  }

  return json({
    customer_id: customer.id,
    name: customer.name,
    avatar_url: customer.avatar_url,
    cashback_balance: Number(customer.cashback_balance),
    subscription_balance: Number(customer.subscription_balance),
    tier: customer.tier,
    visit_count: customer.visit_count,
    active_plan_name: customer.active_plan_name ?? null,
    active_plan_name_ar: customer.active_plan_name_ar ?? null,
  });
});
