import { json, jsonError, preflight } from "../_shared/cors.ts";
import { serviceClient } from "../_shared/supabase.ts";
import { requireOwner } from "../_shared/auth.ts";
import { writeAuditLog } from "../_shared/audit.ts";

type Body = {
  phone: string;
  name: string;
  branch?: string;
};

function normalizePhone(p: string): string {
  let s = p.replace(/\s/g, "").replace(/^00/, "+");
  if (!s.startsWith("+")) s = `+${s}`;
  return s;
}

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

  if (!body.phone?.trim() || !body.name?.trim()) {
    return jsonError("validation", "missing_fields", 400);
  }

  const phone = normalizePhone(body.phone);
  if (!/^\+966[0-9]{9}$/.test(phone)) {
    return jsonError("validation", "invalid_phone", 400);
  }

  const { data: existing } = await supabase
    .from("staff")
    .select("id")
    .eq("phone", phone)
    .maybeSingle();

  if (existing) {
    return jsonError("validation", "staff_phone_exists", 400);
  }

  const { data: userData, error: authErr } = await supabase.auth.admin.createUser({
    phone,
    phone_confirm: false,
    user_metadata: { full_name: body.name },
  });

  if (authErr || !userData?.user) {
    console.error(authErr);
    return jsonError(
      "auth_error",
      authErr?.message ?? "create_user_failed",
      400,
    );
  }

  const { data: row, error: ie } = await supabase
    .from("staff")
    .insert({
      auth_user_id: userData.user.id,
      name: body.name.trim(),
      phone,
      role: "staff",
      branch: body.branch?.trim() || "main",
      is_active: true,
    })
    .select("id")
    .single();

  if (ie || !row) {
    console.error(ie);
    await supabase.auth.admin.deleteUser(userData.user.id);
    return jsonError("db", ie?.message ?? "insert_failed", 500);
  }

  await writeAuditLog(supabase, {
    actor_id: gate.staff.id,
    actor_type: "owner",
    action: "owner_invite_staff",
    table_name: "staff",
    record_id: row.id as string,
    new_values: { phone, name: body.name },
  });

  return json({ success: true, staff_id: row.id });
});
