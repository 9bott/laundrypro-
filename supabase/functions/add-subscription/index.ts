import { json, jsonError, preflight } from "../_shared/cors.ts";
import { serviceClient } from "../_shared/supabase.ts";
import { requireStaff } from "../_shared/auth.ts";
import { writeAuditLog } from "../_shared/audit.ts";
import { dispatchNotification } from "../_shared/dispatch_notification.ts";
import { trySyncGoogleWalletLoyaltyObject } from "../_shared/google_wallet_loyalty.ts";

type Body = {
  customer_id: string;
  staff_id: string;
  plan_id: string;
  idempotency_key: string;
};

/** Matches app subscription plans screen: silver / gold labels from sort_order rank. */
async function tierForSubscriptionPlan(
  supabase: ReturnType<typeof serviceClient>,
  planId: string,
): Promise<string> {
  const { data: plans, error } = await supabase
    .from("subscription_plans")
    .select("id")
    .eq("is_active", true)
    .order("sort_order", { ascending: true });
  if (error || !plans?.length) return "silver";
  const ids = plans.map((p) => p.id as string);
  const i = ids.indexOf(planId);
  const n = ids.length;
  if (i < 0) return "silver";
  if (n >= 3) {
    if (i === 0) return "silver";
    return "gold";
  }
  if (n === 2) return i === 0 ? "silver" : "gold";
  return "gold";
}

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

  const { customer_id, staff_id, plan_id, idempotency_key } = body;
  if (!customer_id || !staff_id || !plan_id || !idempotency_key) {
    return jsonError("validation", "missing_required_fields", 400);
  }
  if (staffGate.ctx.staff.id !== staff_id) {
    return jsonError("forbidden", "staff_id_mismatch_token", 403);
  }

  const storeId = staffGate.ctx.staff.store_id;

  const { data: existing } = await supabase
    .from("transactions")
    .select("*")
    .eq("idempotency_key", idempotency_key)
    .maybeSingle();

  if (existing) {
    const { data: cust } = await supabase
      .from("customers")
      .select("subscription_balance")
      .eq("id", customer_id)
      .maybeSingle();
    return json({
      success: true,
      duplicate: true,
      transaction: existing,
      new_subscription_balance: Number(cust?.subscription_balance ?? 0),
    });
  }

  const { data: plan, error: pe } = await supabase
    .from("subscription_plans")
    .select("*")
    .eq("id", plan_id)
    .eq("is_active", true)
    .maybeSingle();

  if (pe || !plan) {
    return jsonError("not_found", "plan_not_found", 404);
  }

  const { data: customer, error: ce } = await supabase
    .from("customers")
    .select("*")
    .eq("id", customer_id)
    .maybeSingle();

  if (ce || !customer) {
    return jsonError("not_found", "customer_not_found", 404);
  }

  const credit = Number(plan.credit);
  const price = Number(plan.price);
  const subBefore = Number(customer.subscription_balance);
  const cbBefore = Number(customer.cashback_balance);
  const subAfter = Math.round((subBefore + credit) * 100) / 100;
  const newTier = await tierForSubscriptionPlan(supabase, plan_id);

  const { data: txRow, error: txe } = await supabase
    .from("transactions")
    .insert({
      idempotency_key,
      customer_id,
      staff_id,
      store_id: storeId,
      plan_id,
      type: "subscription",
      amount: price,
      cashback_earned: 0,
      subscription_used: 0,
      cashback_used: 0,
      balance_before_cashback: cbBefore,
      balance_before_subscription: subBefore,
      balance_after_cashback: cbBefore,
      balance_after_subscription: subAfter,
    })
    .select()
    .single();

  if (txe || !txRow) {
    console.error(txe);
    return jsonError("db_error", txe?.message ?? "insert_failed", 500);
  }

  const { error: ue } = await supabase
    .from("customers")
    .update({
      subscription_balance: subAfter,
      active_subscription_plan_id: plan_id,
      active_plan_name: plan.name as string,
      active_plan_name_ar: plan.name_ar as string,
      tier: newTier,
    })
    .eq("id", customer_id);

  if (ue) {
    console.error(ue);
    return jsonError("db_error", ue.message, 500);
  }

  try {
    await dispatchNotification(supabase, {
      customer_id,
      type: "subscription_charge",
      channel: "both",
      data: {
        name: customer.name,
        credit,
        subscription_balance: subAfter,
        balance: subAfter,
      },
      transaction_id: txRow.id as string,
    });
  } catch (e) {
    console.error("Notification failed (non-fatal):", e);
    // Don't throw — let transaction complete.
  }

  await writeAuditLog(supabase, {
    actor_id: staff_id,
    actor_type: "staff",
    action: "add_subscription",
    table_name: "transactions",
    record_id: txRow.id as string,
    new_values: { plan_id, credit, price, subAfter },
  });

  await trySyncGoogleWalletLoyaltyObject(supabase, customer_id);

  return json({
    success: true,
    new_subscription_balance: subAfter,
    transaction: txRow,
    credit_applied: credit,
  });
});
