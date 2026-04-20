import type { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";
import { sendFCMNotification } from "./fcm.ts";

export async function notifyOwner(
  supabase: SupabaseClient,
  input: {
    title: string;
    body: string;
    data?: Record<string, string>;
  },
): Promise<void> {
  const { data: owners, error } = await supabase
    .from("staff")
    .select("fcm_token")
    .eq("role", "owner")
    .eq("is_active", true);

  if (error || !owners?.length) return;

  const tokens = owners
    .map((o) => o.fcm_token as string | null)
    .filter((t): t is string => !!t && t.length > 0);

  await Promise.allSettled(
    tokens.map((token) =>
      sendFCMNotification({
        token,
        title: input.title,
        body: input.body,
        data: input.data,
      })
    ),
  );
}

