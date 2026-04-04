import { json, jsonError, preflight } from "../_shared/cors.ts";
import { serviceClient } from "../_shared/supabase.ts";
import { requireOwner } from "../_shared/auth.ts";
import {
  endOfRiyadhDay,
  riyadhDateString,
  startOfRiyadhDay,
} from "../_shared/time.ts";

type Body = {
  date_from?: string;
  date_to?: string;
  branch?: string;
};

type Metrics = {
  total_revenue: number;
  transaction_count: number;
  new_customers: number;
  cashback_issued: number;
  subscriptions_sold: number;
};

async function branchStaffIds(
  supabase: ReturnType<typeof serviceClient>,
  branch?: string,
): Promise<string[] | null> {
  if (!branch) return null;
  const { data, error } = await supabase
    .from("staff")
    .select("id")
    .eq("branch", branch)
    .eq("is_active", true);
  if (error) {
    console.error(error);
    return [];
  }
  return (data ?? []).map((r) => r.id as string);
}

async function aggregateMetrics(
  supabase: ReturnType<typeof serviceClient>,
  fromIso: string,
  toIso: string,
  staffIds: string[] | null,
): Promise<Metrics> {
  let txQuery = supabase
    .from("transactions")
    .select("amount, type, cashback_earned, staff_id")
    .gte("created_at", fromIso)
    .lte("created_at", toIso);

  if (staffIds && staffIds.length) {
    txQuery = txQuery.in("staff_id", staffIds);
  } else if (staffIds && staffIds.length === 0) {
    return {
      total_revenue: 0,
      transaction_count: 0,
      new_customers: 0,
      cashback_issued: 0,
      subscriptions_sold: 0,
    };
  }

  const { data: txs, error: te } = await txQuery;
  if (te || !txs) {
    console.error(te);
    return {
      total_revenue: 0,
      transaction_count: 0,
      new_customers: 0,
      cashback_issued: 0,
      subscriptions_sold: 0,
    };
  }

  let totalRevenue = 0;
  const txCount = txs.length;
  let cashbackIssued = 0;
  let subscriptionsSold = 0;

  for (const t of txs) {
    cashbackIssued += Number(t.cashback_earned ?? 0);
    if (t.type === "purchase" || t.type === "subscription") {
      totalRevenue += Number(t.amount ?? 0);
    }
    if (t.type === "subscription") {
      subscriptionsSold += Number(t.amount ?? 0);
    }
  }

  const { count: newCustomers } = await supabase
    .from("customers")
    .select("id", { count: "exact", head: true })
    .gte("created_at", fromIso)
    .lte("created_at", toIso);

  return {
    total_revenue: Math.round(totalRevenue * 100) / 100,
    transaction_count: txCount,
    new_customers: newCustomers ?? 0,
    cashback_issued: Math.round(cashbackIssued * 100) / 100,
    subscriptions_sold: Math.round(subscriptionsSold * 100) / 100,
  };
}

async function staffActivityForPeriod(
  supabase: ReturnType<typeof serviceClient>,
  fromIso: string,
  toIso: string,
  staffIds: string[] | null,
): Promise<
  Array<{
    staff_name: string;
    transaction_count: number;
    total_processed: number;
  }>
> {
  let q = supabase
    .from("transactions")
    .select("staff_id, amount")
    .gte("created_at", fromIso)
    .lte("created_at", toIso)
    .not("staff_id", "is", null);

  if (staffIds && staffIds.length) q = q.in("staff_id", staffIds);
  else if (staffIds && staffIds.length === 0) return [];

  const { data: txs, error } = await q;
  if (error || !txs?.length) return [];

  const ids = [...new Set(txs.map((t) => t.staff_id as string))];
  const { data: staffRows } = await supabase
    .from("staff")
    .select("id, name")
    .in("id", ids);
  const nameById = new Map(
    (staffRows ?? []).map((s) => [s.id as string, s.name as string]),
  );

  const map = new Map<
    string,
    { staff_name: string; transaction_count: number; total_processed: number }
  >();

  for (const row of txs) {
    const sid = row.staff_id as string;
    const sname = nameById.get(sid) ?? "Unknown";
    const cur = map.get(sid) ?? {
      staff_name: sname,
      transaction_count: 0,
      total_processed: 0,
    };
    cur.transaction_count += 1;
    cur.total_processed += Number(row.amount ?? 0);
    map.set(sid, cur);
  }
  return [...map.values()];
}

async function revenueLast7Days(
  supabase: ReturnType<typeof serviceClient>,
  staffIds: string[] | null,
): Promise<Array<{ date: string; revenue: number }>> {
  const out: Array<{ date: string; revenue: number }> = [];
  for (let i = 6; i >= 0; i--) {
    const dayAnchor = new Date(Date.now() - i * 24 * 60 * 60 * 1000);
    const fromIso = startOfRiyadhDay(dayAnchor).toISOString();
    const toIso = endOfRiyadhDay(dayAnchor).toISOString();
    const ymd = riyadhDateString(dayAnchor);

    if (staffIds && staffIds.length === 0) {
      out.push({ date: ymd, revenue: 0 });
      continue;
    }

    let q = supabase
      .from("transactions")
      .select("amount, type")
      .gte("created_at", fromIso)
      .lte("created_at", toIso)
      .in("type", ["purchase", "subscription"]);

    if (staffIds && staffIds.length) {
      q = q.in("staff_id", staffIds);
    }

    const { data: txs, error } = await q;
    if (error || !txs?.length) {
      out.push({ date: ymd, revenue: 0 });
      continue;
    }
    let rev = 0;
    for (const t of txs) {
      rev += Number(t.amount ?? 0);
    }
    out.push({
      date: ymd,
      revenue: Math.round(rev * 100) / 100,
    });
  }
  return out;
}

async function topCustomersThisMonth(
  supabase: ReturnType<typeof serviceClient>,
  staffIds: string[] | null,
): Promise<Array<{ name: string; total_spent: number; visit_count: number }>> {
  const ymdToday = riyadhDateString(new Date());
  const [yy, mm] = ymdToday.split("-");
  const monthStart = startOfRiyadhDay(
    new Date(`${yy}-${mm}-01T12:00:00+03:00`),
  ).toISOString();
  const monthEnd = endOfRiyadhDay(new Date()).toISOString();

  if (staffIds && staffIds.length === 0) return [];

  let txq = supabase
    .from("transactions")
    .select("customer_id")
    .gte("created_at", monthStart)
    .lte("created_at", monthEnd);

  if (staffIds && staffIds.length) {
    txq = txq.in("staff_id", staffIds);
  }

  const { data: txs } = await txq;
  const freq = new Map<string, number>();
  for (const row of txs ?? []) {
    const cid = row.customer_id as string;
    freq.set(cid, (freq.get(cid) ?? 0) + 1);
  }
  const ids = [...freq.entries()]
    .sort((a, b) => b[1] - a[1])
    .slice(0, 5)
    .map(([id]) => id);

  if (!ids.length) {
    const { data: fallback } = await supabase
      .from("customers")
      .select("name, total_spent, visit_count")
      .eq("is_blocked", false)
      .order("total_spent", { ascending: false })
      .limit(5);
    return (fallback ?? []).map((c) => ({
      name: c.name as string,
      total_spent: Number(c.total_spent),
      visit_count: c.visit_count as number,
    }));
  }

  const { data: custs } = await supabase
    .from("customers")
    .select("name, total_spent, visit_count")
    .in("id", ids);

  const list = (custs ?? []).map((c) => ({
    name: c.name as string,
    total_spent: Number(c.total_spent),
    visit_count: c.visit_count as number,
  }));
  return list.sort((a, b) => b.visit_count - a.visit_count);
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return preflight();

  const supabase = serviceClient();
  const ownerGate = await requireOwner(supabase, req.headers.get("Authorization"));
  if (!ownerGate.ok) {
    return jsonError("unauthorized", ownerGate.message, ownerGate.status);
  }

  let body: Body = {};
  if (req.method === "POST") {
    try {
      body = (await req.json()) as Body;
    } catch { /* ok */ }
  }

  const todayStart = startOfRiyadhDay().toISOString();
  const todayEnd = endOfRiyadhDay().toISOString();

  const dateFrom = body.date_from
    ? new Date(body.date_from).toISOString()
    : startOfRiyadhDay(new Date(Date.now() - 29 * 24 * 60 * 60 * 1000))
      .toISOString();
  const dateTo = body.date_to
    ? new Date(body.date_to).toISOString()
    : endOfRiyadhDay().toISOString();

  const staffIds = await branchStaffIds(supabase, body.branch);

  const thirtyAgo = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000)
    .toISOString();

  const [
    today,
    period,
    topCustomersMonth,
    staffActivity,
    staffActivityToday,
    fraudCount,
    activeRes,
    chart7d,
  ] = await Promise.all([
    aggregateMetrics(supabase, todayStart, todayEnd, staffIds),
    aggregateMetrics(supabase, dateFrom, dateTo, staffIds),
    topCustomersThisMonth(supabase, staffIds),
    staffActivityForPeriod(supabase, dateFrom, dateTo, staffIds),
    staffActivityForPeriod(supabase, todayStart, todayEnd, staffIds),
    supabase
      .from("fraud_flags")
      .select("id", { count: "exact", head: true })
      .eq("resolved", false),
    (async () => {
      if (staffIds && staffIds.length === 0) return { data: [] };
      let q = supabase
        .from("transactions")
        .select("customer_id")
        .gte("created_at", thirtyAgo);
      if (staffIds && staffIds.length) {
        q = q.in("staff_id", staffIds);
      }
      return q;
    })(),
    revenueLast7Days(supabase, staffIds),
  ]);

  const activeSet = new Set(
    (activeRes.data ?? []).map((r) => r.customer_id as string),
  );

  return json({
    success: true,
    today,
    period,
    top_customers: topCustomersMonth,
    staff_activity: staffActivity,
    staff_activity_today: staffActivityToday,
    chart_7d: chart7d,
    fraud_alerts_count: fraudCount.count ?? 0,
    active_customers_30d: activeSet.size,
  });
});
