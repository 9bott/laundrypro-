import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { json, jsonError, preflight } from "../_shared/cors.ts";
import { requireCustomerId } from "../_shared/auth.ts";
import { serviceClient } from "../_shared/supabase.ts";
import { trySyncGoogleWalletLoyaltyObject } from "../_shared/google_wallet_loyalty.ts";
import { sendFCMNotification } from "../_shared/fcm.ts";

serve(async (req) => {
  if (req.method === "OPTIONS") return preflight();

  try {
    const supabase = serviceClient();
    const authHeader = req.headers.get("Authorization");

    const auth = await requireCustomerId(supabase, authHeader);
    if (!auth.ok) {
      return jsonError(auth.message, "Unauthorized", auth.status);
    }

    const customerId = auth.customerId;

    // Check if already received welcome bonus
    const { data: existingBonus, error: existingErr } = await supabase
      .from("transactions")
      .select("id")
      .eq("customer_id", customerId)
      .eq("type", "cashback_bonus")
      .eq("notes", "welcome_bonus")
      .limit(1);

    if (existingErr) {
      return jsonError("check_failed", existingErr.message, 400);
    }

    if (existingBonus && existingBonus.length > 0) {
      return json({ success: false, already_received: true }, 200);
    }

    const bonusAmount = 10.0;

    // Load current balance (simple approach; service_role bypasses RLS)
    const { data: customerRow, error: custErr } = await supabase
      .from("customers")
      .select("id, cashback_balance")
      .eq("id", customerId)
      .single();

    if (custErr || !customerRow) {
      return jsonError("customer_not_found", custErr?.message ?? "not_found", 404);
    }

    const current = Number(customerRow.cashback_balance ?? 0);
    const next = current + bonusAmount;

    const { error: updErr } = await supabase
      .from("customers")
      .update({ cashback_balance: next })
      .eq("id", customerId);

    if (updErr) {
      return jsonError("update_failed", updErr.message, 400);
    }

    const { error: txErr } = await supabase.from("transactions").insert({
      customer_id: customerId,
      type: "cashback_bonus",
      amount: bonusAmount,
      cashback_earned: bonusAmount,
      notes: "welcome_bonus",
      is_undone: false,
    });

    if (txErr) {
      return jsonError("transaction_failed", txErr.message, 400);
    }

    await trySyncGoogleWalletLoyaltyObject(supabase, customerId);

    // FCM push (welcome)
    try {
      const { data: tokRow } = await supabase
        .from("customers")
        .select("fcm_token, device_token")
        .eq("id", customerId)
        .maybeSingle();
      const token = String(tokRow?.fcm_token ?? tokRow?.device_token ?? "");
      if (token) {
        await sendFCMNotification({
          token,
          title: "أهلاً بك في بوينت! 🎉",
          body: "تم إنشاء حسابك بنجاح. ابدأ بمسح QR المتجر!",
          data: { type: "welcome" },
        });
      }
    } catch (e) {
      console.warn("[fcm] welcome push failed", e);
    }

    return json({ success: true, bonus_amount: bonusAmount }, 200);
  } catch (e) {
    return jsonError("unexpected", `${e}`, 400);
  }
});

