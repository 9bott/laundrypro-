import { json, preflight } from "../_shared/cors.ts";
import { serviceClient } from "../_shared/supabase.ts";
import { requireServiceRole } from "../_shared/auth.ts";
import { dispatchNotification } from "../_shared/dispatch_notification.ts";
import { writeAuditLog } from "../_shared/audit.ts";
import { riyadhDateString } from "../_shared/time.ts";

/** Allows `Authorization: Bearer SERVICE_ROLE_KEY` (pg_cron) or `x-cron-secret`. */
function authorizeCron(req: Request): boolean {
  if (requireServiceRole(req.headers.get("Authorization"))) return true;
  const key = Deno.env.get("CRON_SECRET");
  if (!key) return true;
  return req.headers.get("x-cron-secret") === key;
}

async function recentNotifyExists(
  supabase: ReturnType<typeof serviceClient>,
  customerId: string,
  type: string,
  sinceIso: string,
): Promise<boolean> {
  const { data, error } = await supabase
    .from("notifications_log")
    .select("id")
    .eq("customer_id", customerId)
    .eq("type", type)
    .gte("sent_at", sinceIso)
    .limit(1);
  if (error) {
    console.error(error);
    return true;
  }
  return (data?.length ?? 0) > 0;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return preflight();
  if (req.method !== "POST" && req.method !== "GET") {
    return json({ error: "method_not_allowed" }, 405);
  }
  if (!authorizeCron(req)) {
    return json({ error: "unauthorized" }, 401);
  }

  const supabase = serviceClient();
  const now = new Date();
  const cutoffDormant = new Date(now.getTime() - 21 * 24 * 60 * 60 * 1000)
    .toISOString();
  const thirtyDaysAgo = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000)
    .toISOString();
  const fourteenDaysAgo = new Date(now.getTime() - 14 * 24 * 60 * 60 * 1000)
    .toISOString();
  const sevenDaysAgo = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000)
    .toISOString();
  const twentyFiveDaysAgo = new Date(now.getTime() - 25 * 24 * 60 * 60 * 1000)
    .toISOString();

  const yearStart = `${now.getFullYear()}-01-01T00:00:00+03:00`;

  const summary = {
    dormant_sent: 0,
    low_balance_sent: 0,
    birthdays_processed: 0,
    expiry_warnings_sent: 0,
  };

  // —— dormant ——
  const { data: dormantCandidates } = await supabase
    .from("customers")
    .select("id, name, subscription_balance, cashback_balance, last_visit_date")
    .eq("is_blocked", false)
    .not("last_visit_date", "is", null)
    .lt("last_visit_date", cutoffDormant);

  for (const c of dormantCandidates ?? []) {
    const dup = await recentNotifyExists(
      supabase,
      c.id as string,
      "dormant",
      thirtyDaysAgo,
    );
    if (dup) continue;
    const bal =
      Number(c.subscription_balance ?? 0) + Number(c.cashback_balance ?? 0);
    await dispatchNotification(supabase, {
      customer_id: c.id as string,
      type: "dormant",
      channel: "sms",
      data: { name: c.name, balance: bal },
    });
    summary.dormant_sent++;
  }

  // —— low subscription balance ——
  const { data: lowBal } = await supabase
    .from("customers")
    .select("id, name, subscription_balance")
    .eq("is_blocked", false)
    .gt("subscription_balance", 0)
    .lt("subscription_balance", 20);

  for (const c of lowBal ?? []) {
    const dup = await recentNotifyExists(
      supabase,
      c.id as string,
      "low_balance",
      fourteenDaysAgo,
    );
    if (dup) continue;
    await dispatchNotification(supabase, {
      customer_id: c.id as string,
      type: "low_balance",
      channel: "sms",
      data: {
        name: c.name,
        balance: Number(c.subscription_balance),
        bonus: 20,
      },
    });
    summary.low_balance_sent++;
  }

  // —— birthdays (Riyadh calendar day) ——
  const todayMd = riyadhDateString(now).slice(5); // MM-DD from en-CA is YYYY-MM-DD
  const { data: birthdayCustomers } = await supabase
    .from("customers")
    .select("id, name, birthday, cashback_balance, subscription_balance")
    .eq("is_blocked", false)
    .not("birthday", "is", null);

  for (const c of birthdayCustomers ?? []) {
    const bd = c.birthday as string;
    if (!bd || bd.length < 5) continue;
    const md = bd.slice(5, 10);
    if (md !== todayMd) continue;

    const { data: already } = await supabase
      .from("transactions")
      .select("id")
      .eq("customer_id", c.id as string)
      .eq("type", "birthday_bonus")
      .gte("created_at", yearStart)
      .limit(1);
    if ((already?.length ?? 0) > 0) continue;

    const cbBefore = Number(c.cashback_balance ?? 0);
    const subBefore = Number(c.subscription_balance ?? 0);
    const bonus = 10;
    const cbAfter = Math.round((cbBefore + bonus) * 100) / 100;

    const { data: btx, error: bte } = await supabase
      .from("transactions")
      .insert({
        customer_id: c.id as string,
        type: "birthday_bonus",
        amount: 0,
        cashback_earned: bonus,
        subscription_used: 0,
        cashback_used: 0,
        balance_before_cashback: cbBefore,
        balance_before_subscription: subBefore,
        balance_after_cashback: cbAfter,
        balance_after_subscription: subBefore,
      })
      .select()
      .single();

    if (bte) {
      console.error(bte);
      continue;
    }

    await supabase
      .from("customers")
      .update({ cashback_balance: cbAfter })
      .eq("id", c.id as string);

    await dispatchNotification(supabase, {
      customer_id: c.id as string,
      type: "birthday",
      channel: "sms",
      data: { name: c.name, balance: cbAfter },
      transaction_id: btx?.id as string,
    });

    await writeAuditLog(supabase, {
      actor_id: c.id as string,
      actor_type: "system",
      action: "birthday_bonus",
      table_name: "transactions",
      record_id: btx?.id as string,
      new_values: { bonus },
    });

    summary.birthdays_processed++;
  }

  // —— subscription “expiry” warning ——
  const { data: subBalances } = await supabase
    .from("customers")
    .select("id, name, subscription_balance")
    .eq("is_blocked", false)
    .gt("subscription_balance", 0);

  for (const c of subBalances ?? []) {
    const { data: lastSub } = await supabase
      .from("transactions")
      .select("created_at")
      .eq("customer_id", c.id as string)
      .eq("type", "subscription")
      .order("created_at", { ascending: false })
      .limit(1)
      .maybeSingle();

    if (!lastSub?.created_at) continue;
    if (new Date(lastSub.created_at as string) > new Date(twentyFiveDaysAgo)) {
      continue;
    }

    const dup = await recentNotifyExists(
      supabase,
      c.id as string,
      "subscription_expiry",
      sevenDaysAgo,
    );
    if (dup) continue;

    await dispatchNotification(supabase, {
      customer_id: c.id as string,
      type: "subscription_expiry",
      channel: "sms",
      data: {
        name: c.name,
        balance: Number(c.subscription_balance),
      },
    });
    summary.expiry_warnings_sent++;
  }

  return json({ success: true, summary });
});
