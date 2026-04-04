import { json, jsonError, preflight } from "../_shared/cors.ts";
import { serviceClient } from "../_shared/supabase.ts";
import { requireOwner } from "../_shared/auth.ts";
import { writeAuditLog } from "../_shared/audit.ts";

type Body = { customer_id: string; is_blocked: boolean; reason?: string };

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

  if (!body.customer_id || typeof body.is_blocked !== "boolean") {
    return jsonError("validation", "missing_fields", 400);
  }

  const { error: ue } = await supabase
    .from("customers")
    .update({ is_blocked: body.is_blocked })
    .eq("id", body.customer_id);

  if (ue) return jsonError("db", ue.message, 500);

  await writeAuditLog(supabase, {
    actor_id: gate.staff.id,
    actor_type: "owner",
    action: "owner_set_blocked",
    table_name: "customers",
    record_id: body.customer_id,
    new_values: { is_blocked: body.is_blocked, reason: body.reason },
  });

  return json({ success: true });
});
