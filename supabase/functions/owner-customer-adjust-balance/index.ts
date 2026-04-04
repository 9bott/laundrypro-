import { json, jsonError, preflight } from "../_shared/cors.ts";
import { serviceClient } from "../_shared/supabase.ts";
import { requireOwner } from "../_shared/auth.ts";
import { writeAuditLog } from "../_shared/audit.ts";

type Body={
  customer_id: string;
  delta_subscription?: number;
  delta_cashback?: number;
  reason: string;
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return preflight();
  if (req.method !== "POST") return jsonError("method", "POST only", 405);

  const supabase = serviceClient();
  const gate = await requireOwner(supabase, req.headers.get("Authorization"));
  if (!gate.ok) return jsonError("unauthorized", gate.message, gate.status);

  let body: Body;
  try {
    body = (await req.json()) as Body;
  } catch {
    return jsonError("bad_json", "Invalid JSON", 400);
  }

  const ds = Number(body.delta_subscription ?? 0);
  const dc = Number(body.delta_cashback ?? 0);
  if (!body.customer_id || !body.reason?.trim()) {
    return jsonError("validation", "missing_fields", 400);
  }
  if (ds === 0 && dc === 0) {
    return jsonError("validation", "at_least_one_delta", 400);
  }

  const { data: cust, error: ce } = await supabase
    .from("customers")
    .select("*")
    .eq("id", body.customer_id)
    .maybeSingle();
  if (ce || !cust) return jsonError("not_found", "customer_not_found", 404);

  const sub = Math.round((Number(cust.subscription_balance) + ds) * 100) / 100;
  const cb = Math.round((Number(cust.cashback_balance) + dc) * 100) / 100;
  if (sub < 0 || cb < 0) {
    return jsonError("validation", "negative_balance", 400);
  }

  const { error: ue } = await supabase
    .from("customers")
    .update({
      subscription_balance: sub,
      cashback_balance: cb,
    })
    .eq("id", body.customer_id);

  if (ue) return jsonError("db", ue.message, 500);

  await writeAuditLog(supabase, {
    actor_id: gate.staff.id,
    actor_type: "owner",
    action: "owner_adjust_balance",
    table_name: "customers",
    record_id: body.customer_id,
    new_values: { ds, dc, reason: body.reason },
  });

  return json({
    success: true,
    new_subscription_balance: sub,
    new_cashback_balance: cb,
  });
});
