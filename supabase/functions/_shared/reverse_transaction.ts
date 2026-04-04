import { serviceClient } from "./supabase.ts";

type Supabase = ReturnType<typeof serviceClient>;

/** Reverse a single transaction (purchase | redemption | subscription). Returns error message or null. */
export async function reverseTransactionById(
  supabase: Supabase,
  txId: string,
  undoneByStaffId: string,
): Promise<string | null> {
  const { data: tx, error: te } = await supabase
    .from("transactions")
    .select("*")
    .eq("id", txId)
    .maybeSingle();

  if (te || !tx) return "not_found";
  if (tx.is_undone) return "already_undone";

  const { data: customer, error: ce } = await supabase
    .from("customers")
    .select("*")
    .eq("id", tx.customer_id)
    .maybeSingle();

  if (ce || !customer) return "customer_not_found";

  const type = tx.type as string;
  let patch: Record<string, unknown> = {};

  if (type === "purchase") {
    const cb = Number(customer.cashback_balance) -
      Number(tx.cashback_earned ?? 0);
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
    return "type_not_supported";
  }

  const { error: ue } = await supabase
    .from("customers")
    .update(patch)
    .eq("id", tx.customer_id);

  if (ue) return ue.message;

  await supabase
    .from("transactions")
    .update({
      is_undone: true,
      undone_at: new Date().toISOString(),
      undone_by: undoneByStaffId,
    })
    .eq("id", txId);

  return null;
}
