import { json, jsonError, preflight } from "../_shared/cors.ts";
import { serviceClient } from "../_shared/supabase.ts";
import { requireServiceRole } from "../_shared/auth.ts";
import { notifyOwner } from "../_shared/owner_notify.ts";

type Body = {
  title: string;
  body: string;
  data?: Record<string, string>;
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return preflight();

  if (!requireServiceRole(req.headers.get("Authorization"))) {
    return jsonError("unauthorized", "service_role_only", 401);
  }

  let body: Body;
  try {
    body = (await req.json()) as Body;
  } catch {
    return jsonError("bad_json", "Invalid JSON body", 400);
  }

  if (!body.title || !body.body) {
    return jsonError("validation", "missing_required_fields", 400);
  }

  const supabase = serviceClient();
  await notifyOwner(supabase, {
    title: body.title,
    body: body.body,
    data: body.data,
  });

  return json({ success: true });
});

