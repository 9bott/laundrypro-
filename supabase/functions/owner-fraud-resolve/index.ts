import { json, jsonError, preflight } from "../_shared/cors.ts";
import { serviceClient } from "../_shared/supabase.ts";
import { requireOwner } from "../_shared/auth.ts";
import { writeAuditLog } from "../_shared/audit.ts";
import { reverseTransactionById } from "../_shared/reverse_transaction.ts";

type Body = {
  flag_id: string;
  action: "review" | "reverse";
  notes?: string;
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

  if (!body.flag_id || (body.action !== "review" && body.action !== "reverse")) {
    return jsonError("validation", "missing_fields", 400);
  }

  const { data: flag, error: fe } = await supabase
    .from("fraud_flags")
    .select("*")
    .eq("id", body.flag_id)
    .maybeSingle();

  if (fe || !flag) return jsonError("not_found", "flag_not_found", 404);
  if (flag.resolved) return jsonError("validation", "already_resolved", 400);

  if (body.action === "reverse") {
    const txId = flag.transaction_id as string | null;
    if (!txId) {
      return jsonError("validation", "no_transaction", 400);
    }
    const err = await reverseTransactionById(supabase, txId, gate.staff.id);
    if (err) return jsonError("reverse_failed", err, 400);

    await writeAuditLog(supabase, {
      actor_id: gate.staff.id,
      actor_type: "owner",
      action: "owner_fraud_reverse",
      table_name: "transactions",
      record_id: txId,
      new_values: { flag_id: body.flag_id },
    });
  }

  const { error: ue } = await supabase
    .from("fraud_flags")
    .update({
      resolved: true,
      reviewed_by: gate.staff.id,
      notes: body.notes ?? (body.action === "review" ? "reviewed" : "reversed"),
    })
    .eq("id", body.flag_id);

  if (ue) return jsonError("db", ue.message, 500);

  await writeAuditLog(supabase, {
    actor_id: gate.staff.id,
    actor_type: "owner",
    action: "owner_fraud_resolve",
    table_name: "fraud_flags",
    record_id: body.flag_id,
    new_values: { action: body.action },
  });

  return json({ success: true });
});
