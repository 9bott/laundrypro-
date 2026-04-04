import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

export function supabaseAdmin() {
  const url = Deno.env.get("SUPABASE_URL") ?? "";
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  if (!url || !key) {
    throw new Error("missing_supabase_env");
  }
  return createClient(url, key, {
    auth: { persistSession: false, autoRefreshToken: false },
    global: { headers: { "X-Client-Info": "wallet-edge/1.0" } },
  });
}

