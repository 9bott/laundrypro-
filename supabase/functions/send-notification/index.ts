import { json, jsonError, preflight } from "../_shared/cors.ts";
import { serviceClient } from "../_shared/supabase.ts";
import { requireServiceRole } from "../_shared/auth.ts";
import {
  dispatchNotification,
  type NotifyChannel,
  type NotifyType,
} from "../_shared/dispatch_notification.ts";

type Body = {
  customer_id: string;
  type: NotifyType;
  channel: NotifyChannel;
  data: Record<string, unknown>;
  transaction_id?: string | null;
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

  if (!body.customer_id || !body.type || !body.channel) {
    return jsonError("validation", "missing_required_fields", 400);
  }

  const supabase = serviceClient();
  await dispatchNotification(supabase, {
    customer_id: body.customer_id,
    type: body.type,
    channel: body.channel,
    data: body.data ?? {},
    transaction_id: body.transaction_id ?? null,
  });

  return json({ success: true });
});
