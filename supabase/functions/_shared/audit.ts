import type { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";

export async function writeAuditLog(
  supabase: SupabaseClient,
  row: {
    actor_id: string;
    actor_type: "customer" | "staff" | "owner" | "system";
    action: string;
    table_name?: string | null;
    record_id?: string | null;
    old_values?: Record<string, unknown> | null;
    new_values?: Record<string, unknown> | null;
    device_id?: string | null;
  },
): Promise<void> {
  const { error } = await supabase.from("audit_log").insert({
    actor_id: row.actor_id,
    actor_type: row.actor_type,
    action: row.action,
    table_name: row.table_name ?? null,
    record_id: row.record_id ?? null,
    old_values: row.old_values ?? null,
    new_values: row.new_values ?? null,
    device_id: row.device_id ?? null,
  });
  if (error) console.error("[audit_log]", error);
}
