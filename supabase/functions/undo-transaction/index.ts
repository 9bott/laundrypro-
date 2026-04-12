import { json } from "../_shared/cors.ts";
import { serviceClient } from "../_shared/supabase.ts";
import { requireStaff } from "../_shared/auth.ts";
import { writeAuditLog } from "../_shared/audit.ts";
import { trySyncGoogleWalletLoyaltyObject } from "../_shared/google_wallet_loyalty.ts";

/**
 * Undoes a transaction within ~35s of creation (staff UX target 30s).
 * Reverses balances using row snapshot fields.
 */
Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return json({ error: "method_not_allowed" }, 405);
  }

  const supabase = serviceClient();
  const gate = await requireStaff(supabase, req.headers.get("Authorization"));
  if (!gate.ok) {
    return json({ error: gate.message }, gate.status);
  }

  let body: { transaction_id?: string; staff_id?: string };
  try {
    body = (await req.json()) as typeof body;
  } catch {
    return json({ error: "bad_json" }, 400);
  }

  const txId = body.transaction_id;
  const staffId = body.staff_id;
  if (!txId || !staffId) {
    return json({ error: "missing_fields" }, 400);
  }
  if (staffId !== gate.ctx.staff.id) {
    return json({ error: "staff_mismatch" }, 403);
  }

  const { data: tx, error: te } = await supabase
    .from("transactions")
    .select("*")
    .eq("id", txId)
    .maybeSingle();

  if (te || !tx) {
    return json({ error: "not_found" }, 404);
  }

  if (tx.is_undone) {
    return json({ error: "already_undone" }, 400);
  }

  const created = new Date(tx.created_at as string).getTime();
  if (Date.now() - created > 35_000) {
    return json({ error: "undo_window_expired" }, 400);
  }

  const { data: customer, error: ce } = await supabase
    .from("customers")
    .select("*")
    .eq("id", tx.customer_id)
    .maybeSingle();

  if (ce || !customer) {
    return json({ error: "customer_not_found" }, 404);
  }

  const type = tx.type as string;
  let patch: Record<string, unknown> = {};

  if (type === "purchase") {
    const cb = Number(customer.cashback_balance) - Number(tx.cashback_earned ?? 0);
    const spent = Number(customer.total_spent) - Number(tx.amount ?? 0);
    const visits = Math.max(0, (customer.visit_count as number) - 1);
    patch = {
      cashback_balance: cb,
      total_spent: Math.max(0, spent),
      visit_count: visits,
    };
  } else if (type === "redemption") {
    patch = {
      subscription_balance: Number(customer.subscription_balance) +
        Number(tx.subscription_used ?? 0),
      cashback_balance: Number(customer.cashback_balance) +
        Number(tx.cashback_used ?? 0),
    };
  } else if (type === "subscription") {
    const credit = Number(tx.balance_after_subscription) -
      Number(tx.balance_before_subscription);
    patch = {
      subscription_balance: Math.max(
        0,
        Number(customer.subscription_balance) - credit,
      ),
    };
  } else {
    return json({ error: "type_not_supported_for_undo" }, 400);
  }

  const { error: ue } = await supabase
    .from("customers")
    .update(patch)
    .eq("id", tx.customer_id);

  if (ue) {
    console.error(ue);
    return json({ error: ue.message }, 500);
  }

  await supabase
    .from("transactions")
    .update({
      is_undone: true,
      undone_at: new Date().toISOString(),
      undone_by: staffId,
    })
    .eq("id", txId);

  await writeAuditLog(supabase, {
    actor_id: staffId,
    actor_type: "staff",
    action: "undo_transaction",
    table_name: "transactions",
    record_id: txId,
    new_values: { type },
  });

  await trySyncGoogleWalletLoyaltyObject(supabase, tx.customer_id as string);

  return json({ success: true });
});
