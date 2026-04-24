import { json, jsonError, preflight } from "../_shared/cors.ts";
import { serviceClient } from "../_shared/supabase.ts";
import { notifyOwner } from "../_shared/owner_notify.ts";
import { sendFCMNotification } from "../_shared/fcm.ts";

type Body = {
  title: string;
  body: string;
  data?: Record<string, string>;
  fcm_token?: string; // optional direct token
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return preflight();

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
  if (body.fcm_token) {
    // Send directly to provided token
    try {
      await sendFCMNotification({
        token: body.fcm_token,
        title: body.title,
        body: body.body,
        data: body.data,
      });
    } catch (e) {
      console.error("[notify-owner] FCM failed:", e);
    }
  } else {
    // Fall back to notifyOwner (staff table lookup)
    await notifyOwner(supabase, {
      title: body.title,
      body: body.body,
      data: body.data,
    });
  }

  return json({ success: true });
});

