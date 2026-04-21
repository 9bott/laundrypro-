import { json, jsonError, preflight } from "../_shared/cors.ts";
import { serviceClient } from "../_shared/supabase.ts";
import { requireStaff } from "../_shared/auth.ts";
import { writeAuditLog } from "../_shared/audit.ts";
import { trySyncGoogleWalletLoyaltyObject } from "../_shared/google_wallet_loyalty.ts";
import { dispatchNotification } from "../_shared/dispatch_notification.ts";

type Body = {
  customer_id: string;
  staff_id: string;
  amount: number;
  idempotency_key: string;
};

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

  const { customer_id, staff_id, amount, idempotency_key } = body;
  if (!customer_id || !staff_id || !idempotency_key || typeof amount !== "number") {
    return jsonError("validation", "missing_required_fields", 400);
  }
  if (amount <= 0) {
    return jsonError("validation", "amount_must_be_positive", 400);
  }
  if (staffGate.ctx.staff.id !== staff_id) {
    return jsonError("forbidden", "staff_id_mismatch_token", 403);
  }

  const { data: existing } = await supabase
    .from("transactions")
    .select("*")
    .eq("idempotency_key", idempotency_key)
    .maybeSingle();

  if (existing) {
    const { data: cust } = await supabase
      .from("customers")
      .select("subscription_balance, cashback_balance")
      .eq("id", customer_id)
      .maybeSingle();
    return json({
      success: true,
      duplicate: true,
      subscription_used: Number(existing.subscription_used),
      cashback_used: Number(existing.cashback_used),
      transaction: existing,
      new_subscription_balance: Number(cust?.subscription_balance ?? 0),
      new_cashback_balance: Number(cust?.cashback_balance ?? 0),
    });
  }

  const { data: customer, error: ce } = await supabase
    .from("customers")
    .select("*")
    .eq("id", customer_id)
    .maybeSingle();

  if (ce || !customer) {
    return jsonError("not_found", "customer_not_found", 404);
  }

  const subBefore = Number(customer.subscription_balance);
  const cbBefore = Number(customer.cashback_balance);
  const totalAvail = Math.round((subBefore + cbBefore) * 100) / 100;
  const amt = Math.round(amount * 100) / 100;

  if (totalAvail < amt) {
    return jsonError("insufficient_balance", "insufficient_balance", 400);
  }

  let subscriptionUsed = 0;
  let cashbackUsed = 0;
  let subRemain = subBefore;
  let cbRemain = cbBefore;

  subscriptionUsed = Math.min(subRemain, amt);
  subRemain = Math.round((subRemain - subscriptionUsed) * 100) / 100;
  const remainder = Math.round((amt - subscriptionUsed) * 100) / 100;
  if (remainder > 0) {
    cashbackUsed = Math.min(cbRemain, remainder);
    cbRemain = Math.round((cbRemain - cashbackUsed) * 100) / 100;
  }

  const subAfter = subRemain;
  const cbAfter = cbRemain;

  const { data: txRow, error: txe } = await supabase
    .from("transactions")
    .insert({
      idempotency_key,
      customer_id,
      staff_id,
      type: "redemption",
      amount: amt,
      cashback_earned: 0,
      subscription_used: subscriptionUsed,
      cashback_used: cashbackUsed,
      balance_before_cashback: cbBefore,
      balance_before_subscription: subBefore,
      balance_after_cashback: cbAfter,
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
      cashback_balance: cbAfter,
    })
    .eq("id", customer_id);

  if (ue) {
    console.error(ue);
    return jsonError("db_error", ue.message, 500);
  }

  await dispatchNotification(supabase, {
    customer_id,
    type: "transaction",
    channel: "sms",
    data: {
      name: customer.name,
      cashback: 0,
      balance: cbAfter + subAfter,
    },
    transaction_id: txRow.id as string,
  });

  await writeAuditLog(supabase, {
    actor_id: staff_id,
    actor_type: "staff",
    action: "redeem_balance",
    table_name: "transactions",
    record_id: txRow.id as string,
    new_values: {
      subscription_used: subscriptionUsed,
      cashback_used: cashbackUsed,
    },
  });

  await trySyncGoogleWalletLoyaltyObject(supabase, customer_id);

  return json({
    success: true,
    subscription_used: subscriptionUsed,
    cashback_used: cashbackUsed,
    new_subscription_balance: subAfter,
    new_cashback_balance: cbAfter,
    transaction: txRow,
  });
});
