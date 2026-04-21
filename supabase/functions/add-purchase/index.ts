import { json, jsonError, preflight } from "../_shared/cors.ts";
import { serviceClient } from "../_shared/supabase.ts";
import { requireStaff } from "../_shared/auth.ts";
import {
  kCashbackRate,
  kDailyTransactionLimit,
  kFraudLargeAmountSar,
} from "../_shared/constants.ts";
import {
  endOfRiyadhDay,
  startOfRiyadhDay,
  wholeDaysBetweenRiyadh,
} from "../_shared/time.ts";
import { writeAuditLog } from "../_shared/audit.ts";
import { dispatchNotification } from "../_shared/dispatch_notification.ts";
import { trySyncGoogleWalletLoyaltyObject } from "../_shared/google_wallet_loyalty.ts";

type Body = {
  customer_id: string;
  staff_id: string;
  amount: number;
  idempotency_key: string;
  device_id?: string;
};

function tierForTotalSpent(total: number): string {
  if (total < 500) return "bronze";
  if (total < 2000) return "silver";
  return "gold";
}

function normalizePhone(p: string): string {
  return p.replace(/\s/g, "").replace(/^00/, "+");
}

async function runFraudChecks(
  supabase: ReturnType<typeof serviceClient>,
  opts: {
    transactionId: string;
    staffId: string;
    customerId: string;
    staffPhone: string;
    customerPhone: string;
    amount: number;
    deviceId?: string;
  },
): Promise<void> {
  const flags: Array<{
    flag_type: string;
    transaction_id: string;
    staff_id: string;
    customer_id: string;
    auto_detected: boolean;
  }> = [];

  if (normalizePhone(opts.staffPhone) === normalizePhone(opts.customerPhone)) {
    flags.push({
      flag_type: "self_transaction",
      transaction_id: opts.transactionId,
      staff_id: opts.staffId,
      customer_id: opts.customerId,
      auto_detected: true,
    });
  }

  const hourAgo = new Date(Date.now() - 60 * 60 * 1000).toISOString();
  const { count: velCount } = await supabase
    .from("transactions")
    .select("id", { count: "exact", head: true })
    .eq("customer_id", opts.customerId)
    .gte("created_at", hourAgo);

  if ((velCount ?? 0) >= 3) {
    flags.push({
      flag_type: "velocity_exceeded",
      transaction_id: opts.transactionId,
      staff_id: opts.staffId,
      customer_id: opts.customerId,
      auto_detected: true,
    });
  }

  if (opts.amount > kFraudLargeAmountSar) {
    flags.push({
      flag_type: "large_amount",
      transaction_id: opts.transactionId,
      staff_id: opts.staffId,
      customer_id: opts.customerId,
      auto_detected: true,
    });
  }

  if (opts.deviceId) {
    const start = startOfRiyadhDay().toISOString();
    const end = endOfRiyadhDay().toISOString();
    const { data: rows } = await supabase
      .from("transactions")
      .select("customer_id")
      .eq("device_id", opts.deviceId)
      .gte("created_at", start)
      .lte("created_at", end);

    const uniq = new Set((rows ?? []).map((r) => r.customer_id as string));
    uniq.add(opts.customerId);
    if (uniq.size >= 2) {
      flags.push({
        flag_type: "duplicate_device",
        transaction_id: opts.transactionId,
        staff_id: opts.staffId,
        customer_id: opts.customerId,
        auto_detected: true,
      });
    }
  }

  if (flags.length) {
    await supabase.from("fraud_flags").insert(flags);
  }
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

  const { customer_id, staff_id, amount, idempotency_key, device_id } = body;
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
      .select("cashback_balance")
      .eq("id", customer_id)
      .maybeSingle();
    return json({
      success: true,
      duplicate: true,
      transaction: existing,
      new_cashback_balance: Number(cust?.cashback_balance ?? 0),
      cashback_earned: Number(existing.cashback_earned ?? 0),
    });
  }

  const dayStart = startOfRiyadhDay().toISOString();
  const dayEnd = endOfRiyadhDay().toISOString();
  const { count: dayCount } = await supabase
    .from("transactions")
    .select("id", { count: "exact", head: true })
    .eq("customer_id", customer_id)
    .gte("created_at", dayStart)
    .lte("created_at", dayEnd);

  if ((dayCount ?? 0) >= kDailyTransactionLimit) {
    return jsonError("daily_limit_exceeded", "daily_limit_exceeded", 429);
  }

  const { data: customer, error: ce } = await supabase
    .from("customers")
    .select("*")
    .eq("id", customer_id)
    .maybeSingle();

  if (ce || !customer) {
    return jsonError("not_found", "customer_not_found", 404);
  }

  const cbBefore = Number(customer.cashback_balance);
  const subBefore = Number(customer.subscription_balance);
  const cashbackEarned = Math.round(amount * kCashbackRate * 100) / 100;

  const lastVisit = customer.last_visit_date
    ? new Date(customer.last_visit_date as string)
    : null;
  const now = new Date();

  let newStreak = customer.streak_count as number;
  if (!lastVisit) {
    newStreak = 1;
  } else {
    const days = wholeDaysBetweenRiyadh(lastVisit, now);
    if (days > 8) newStreak = 1;
    else if (days >= 6 && days <= 8) newStreak = (customer.streak_count as number) + 1;
  }

  let streakBonus = 0;
  let streakWeekLabel = newStreak;
  if (newStreak >= 4) {
    streakBonus = 10;
    newStreak = 0;
  }

  const newTotalSpent = Number(customer.total_spent) + amount;
  const newTier = tierForTotalSpent(newTotalSpent);
  const cbAfterPurchase = Math.round((cbBefore + cashbackEarned) * 100) / 100;
  const finalCashback =
    Math.round((cbAfterPurchase + streakBonus) * 100) / 100;

  const { data: purchaseTx, error: txe } = await supabase
    .from("transactions")
    .insert({
      idempotency_key,
      customer_id,
      staff_id,
      type: "purchase",
      amount,
      cashback_earned: cashbackEarned,
      subscription_used: 0,
      cashback_used: 0,
      balance_before_cashback: cbBefore,
      balance_before_subscription: subBefore,
      balance_after_cashback: cbAfterPurchase,
      balance_after_subscription: subBefore,
      device_id: device_id ?? null,
    })
    .select()
    .single();

  if (txe || !purchaseTx) {
    console.error(txe);
    return jsonError("db_error", txe?.message ?? "insert_failed", 500);
  }

  const updatePayload: Record<string, unknown> = {
    cashback_balance: finalCashback,
    total_spent: newTotalSpent,
    visit_count: (customer.visit_count as number) + 1,
    last_visit_date: now.toISOString(),
    streak_count: newStreak,
    tier: newTier,
  };

  const { error: ue } = await supabase
    .from("customers")
    .update(updatePayload)
    .eq("id", customer_id);

  if (ue) {
    console.error(ue);
    return jsonError("db_error", ue.message, 500);
  }

  let streakTxId: string | null = null;
  if (streakBonus > 0) {
    const { data: stTx, error: se } = await supabase
      .from("transactions")
      .insert({
        customer_id,
        staff_id,
        type: "streak_bonus",
        amount: 0,
        cashback_earned: streakBonus,
        subscription_used: 0,
        cashback_used: 0,
        balance_before_cashback: cbAfterPurchase,
        balance_before_subscription: subBefore,
        balance_after_cashback: finalCashback,
        balance_after_subscription: subBefore,
        device_id: device_id ?? null,
      })
      .select()
      .single();
    if (se) console.error(se);
    else streakTxId = stTx?.id ?? null;
  }

  await runFraudChecks(supabase, {
    transactionId: purchaseTx.id as string,
    staffId: staff_id,
    customerId: customer_id,
    staffPhone: staffGate.ctx.staff.phone,
    customerPhone: customer.phone as string,
    amount,
    deviceId: device_id,
  });

  try {
    await dispatchNotification(supabase, {
      customer_id,
      type: "transaction",
      channel: "sms",
      data: {
        name: customer.name,
        cashback: cashbackEarned,
        balance: finalCashback,
      },
      transaction_id: purchaseTx.id as string,
    });
  } catch (e) {
    console.error("Notification failed (non-fatal):", e);
    // Don't throw — let transaction complete.
  }

  if (streakBonus > 0) {
    try {
      await dispatchNotification(supabase, {
        customer_id,
        type: "streak",
        channel: "sms",
        data: {
          name: customer.name,
          streak: streakWeekLabel,
          balance: finalCashback,
        },
        transaction_id: streakTxId,
      });
    } catch (e) {
      console.error("Notification failed (non-fatal):", e);
      // Don't throw — let transaction complete.
    }
  }

  await writeAuditLog(supabase, {
    actor_id: staff_id,
    actor_type: "staff",
    action: "add_purchase",
    table_name: "transactions",
    record_id: purchaseTx.id as string,
    new_values: { purchaseTx, streakBonus },
    device_id: device_id ?? null,
  });

  await trySyncGoogleWalletLoyaltyObject(supabase, customer_id);

  return json({
    success: true,
    transaction: purchaseTx,
    new_cashback_balance: finalCashback,
    cashback_earned: cashbackEarned,
    streak_bonus: streakBonus,
  });
});
