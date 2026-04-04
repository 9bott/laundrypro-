export type UnifonicSendResult =
  | { ok: true; raw: unknown }
  | { ok: false; error: string };

/**
 * Sends SMS via Unifonic REST API.
 * https://api.unifonic.com/rest/Messages/Send
 */
export async function sendUnifonicSms(
  recipient: string,
  body: string,
): Promise<UnifonicSendResult> {
  const apiKey = Deno.env.get("UNIFONIC_API_KEY");
  if (!apiKey) {
    console.warn("[sms] UNIFONIC_API_KEY not set — skipping SMS");
    return { ok: false, error: "missing_unifonic_key" };
  }

  const normalized = recipient.startsWith("+")
    ? recipient
    : `+${recipient.replace(/^\+/, "")}`;

  try {
    const res = await fetch("https://api.unifonic.com/rest/Messages/Send", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${apiKey}`,
        "Content-Type": "application/json",
        Accept: "application/json",
      },
      body: JSON.stringify({
        recipient: normalized,
        body,
        senderid: "Point",
      }),
    });

    const raw = await res.json().catch(() => ({}));
    if (!res.ok) {
      return {
        ok: false,
        error: `unifonic_http_${res.status}`,
      };
    }
    return { ok: true, raw };
  } catch (e) {
    return {
      ok: false,
      error: e instanceof Error ? e.message : "unifonic_network_error",
    };
  }
}
