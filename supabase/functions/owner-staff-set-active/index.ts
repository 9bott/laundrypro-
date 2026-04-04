import { json, jsonError, preflight } from "../_shared/cors.ts";
import { serviceClient } from "../_shared/supabase.ts";
import { requireOwner } from "../_shared/auth.ts";
import { writeAuditLog } from "../_shared/audit.ts";

type Body = { staff_id: string; is_active: boolean };

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

  if (!body.staff_id || typeof body.is_active !== "boolean") {
    return jsonError("validation", "missing_fields", 400);
  }

  if (body.staff_id === gate.staff.id && !body.is_active) {
    return jsonError("validation", "cannot_deactivate_self", 400);
  }

  const { error: ue } = await supabase
    .from("staff")
    .update({ is_active: body.is_active })
    .eq("id", body.staff_id);

  if (ue) return jsonError("db", ue.message, 500);

  await writeAuditLog(supabase, {
    actor_id: gate.staff.id,
    actor_type: "owner",
    action: "owner_staff_active",
    table_name: "staff",
    record_id: body.staff_id,
    new_values: { is_active: body.is_active },
  });

  return json({ success: true });
});
