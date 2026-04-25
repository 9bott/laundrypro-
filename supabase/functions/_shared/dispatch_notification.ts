import type { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";
import { sendUnifonicSms } from "./sms.ts";
import { sendFCMNotification } from "./fcm.ts";

export type NotifyType =
  | "transaction"
  | "low_balance"
  | "dormant"
  | "streak"
  | "birthday"
  | "subscription_charge"
  | "subscription_expiry";

export type NotifyChannel = "sms" | "push" | "both";

function templateMessage(
  type: NotifyType,
  data: Record<string, unknown>,
): string {
  const name = String(data.name ?? "عزيزي العميل");
  const cashback = String(data.cashback ?? data.credit ?? "0");
  const balance = String(data.balance ?? "0");
  const streak = String(data.streak ?? "0");
  const bonus = String(data.bonus ?? "20");

  switch (type) {
    case "transaction":
      return `مرحباً ${name}، تم إضافة ${cashback} ريال كاش باك لمحفظتك. رصيدك الآن: ${balance} ريال 💰`;
    case "low_balance":
      return `رصيد اشتراكك ${balance} ريال فقط! اشحن الآن واحصل على ${bonus}% مجاناً`;
    case "dormant":
      return `نفتقدك ${name}! لديك ${balance} ريال تنتظرك في محفظتك 🤍`;
    case "streak":
      return `أسبوع ${streak} على التوالي! تمت إضافة 10 ريال مكافأة لمحفظتك 🎉`;
    case "birthday":
      return `عيد ميلاد سعيد ${name}! هديتك 10 ريال في محفظتك 🎂`;
    case "subscription_charge":
      return `تم شحن محفظتك بـ ${String(data.credit ?? 0)} ريال. رصيد اشتراكك الآن: ${String(data.subscription_balance ?? balance)} ريال`;
    case "subscription_expiry":
      return `${name}، رصيد اشتراكك ${balance} ريال قد لا يكون نشطاً لفترة طويلة — قم بالزيارة أو الشحن لتجنب الفقدان.`;
    default:
      return String(data.fallback_message ?? "Point notification");
  }
}

/**
 * Persists `notifications_log`, sends SMS and/or push per channel.
 */
export async function dispatchNotification(
  supabase: SupabaseClient,
  input: {
    customer_id: string;
    type: NotifyType;
    channel: NotifyChannel;
    data: Record<string, unknown>;
    transaction_id?: string | null;
  },
): Promise<void> {
  const { data: cust, error } = await supabase
    .from("customers")
    .select("phone, name, device_token, fcm_token, preferred_language")
    .eq("id", input.customer_id)
    .maybeSingle();

  if (error || !cust) {
    console.error("[notify] customer not found", error);
    return;
  }

  const message = templateMessage(input.type, {
    ...input.data,
    name: input.data.name ?? cust.name,
  });

  const wantSms = input.channel === "sms" || input.channel === "both";
  const wantPush = input.channel === "push" || input.channel === "both";

  let delivered = false;

  if (wantSms && cust.phone) {
    try {
      const r = await sendUnifonicSms(cust.phone as string, message);
      delivered = r.ok;
    } catch (e) {
      console.error("Notification failed (non-fatal):", e);
      // Don't throw — let transaction complete.
    }
  }

  // Firebase FCM: send directly to the customer's FCM token.
  const pushToken = (cust as { fcm_token?: string | null }).fcm_token;

  if (wantPush && pushToken) {
    try {
      await sendFCMNotification({
        token: pushToken as string,
        title: "Point",
        body: message,
        data: {},
      });
      delivered = true;
    } catch (e) {
      console.error("Notification failed (non-fatal):", e);
      // Don't throw — let transaction complete.
    }
  }

  const logChannel = wantSms && wantPush
    ? "both"
    : wantSms
    ? "sms"
    : "push";

  await supabase.from("notifications_log").insert({
    customer_id: input.customer_id,
    type: input.type,
    channel: logChannel,
    message,
    delivered,
    transaction_id: input.transaction_id ?? null,
  });
}
