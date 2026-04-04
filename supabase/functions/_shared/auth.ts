import type { SupabaseClient, User } from "https://esm.sh/@supabase/supabase-js@2.49.1";

export type StaffAuth = {
  user: User;
  staff: {
    id: string;
    phone: string;
    name: string;
    role: string;
    branch: string;
    is_active: boolean;
  };
};

/**
 * Validates Authorization Bearer JWT and loads an active `staff` row.
 */
export async function requireStaff(
  supabase: SupabaseClient,
  authHeader: string | null,
): Promise<
  | { ok: true; ctx: StaffAuth }
  | { ok: false; status: number; message: string }
> {
  if (!authHeader?.startsWith("Bearer ")) {
    return { ok: false, status: 401, message: "missing_bearer_token" };
  }
  const jwt = authHeader.slice(7);
  const { data: { user }, error } = await supabase.auth.getUser(jwt);
  if (error || !user) {
    return { ok: false, status: 401, message: "invalid_jwt" };
  }

  const { data: staff, error: se } = await supabase
    .from("staff")
    .select("id, phone, name, role, branch, is_active")
    .eq("auth_user_id", user.id)
    .maybeSingle();

  if (se || !staff || !staff.is_active) {
    return { ok: false, status: 403, message: "staff_not_found_or_inactive" };
  }

  return {
    ok: true,
    ctx: {
      user,
      staff: staff as StaffAuth["staff"],
    },
  };
}

/**
 * Validates customer JWT and returns linked `customers.id`.
 */
export async function requireCustomerId(
  supabase: SupabaseClient,
  authHeader: string | null,
): Promise<
  | { ok: true; customerId: string; user: User }
  | { ok: false; status: number; message: string }
> {
  if (!authHeader?.startsWith("Bearer ")) {
    return { ok: false, status: 401, message: "missing_bearer_token" };
  }
  const jwt = authHeader.slice(7);
  const { data: { user }, error } = await supabase.auth.getUser(jwt);
  if (error || !user) {
    return { ok: false, status: 401, message: "invalid_jwt" };
  }

  const { data: row, error: ce } = await supabase
    .from("customers")
    .select("id")
    .eq("auth_user_id", user.id)
    .maybeSingle();

  if (ce || !row) {
    return { ok: false, status: 403, message: "customer_not_linked" };
  }

  return { ok: true, customerId: row.id as string, user };
}

export async function requireOwner(
  supabase: SupabaseClient,
  authHeader: string | null,
): Promise<
  | { ok: true; staff: StaffAuth["staff"]; user: User }
  | { ok: false; status: number; message: string }
> {
  const r = await requireStaff(supabase, authHeader);
  if (!r.ok) return r;
  if (r.ctx.staff.role !== "owner") {
    return { ok: false, status: 403, message: "owner_only" };
  }
  return { ok: true, staff: r.ctx.staff, user: r.ctx.user };
}

/**
 * HTTP entry: only allow invocation with the service-role secret (Edge → Edge or manual ops).
 */
export function requireServiceRole(authHeader: string | null): boolean {
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!key || !authHeader?.startsWith("Bearer ")) return false;
  return authHeader.slice(7) === key;
}
