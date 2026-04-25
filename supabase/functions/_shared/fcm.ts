export async function sendFCMNotification(input: {
  token: string;
  title: string;
  body: string;
  data?: Record<string, string>;
}): Promise<unknown> {
  const instanceId = Deno.env.get("PUSHER_INSTANCE_ID");
  const secretKey = Deno.env.get("PUSHER_SECRET_KEY");

  if (!instanceId || !secretKey) {
    throw new Error("[Pusher] Missing credentials");
  }

  const response = await fetch(
    `https://${instanceId}.pushnotifications.pusher.com/publish_api/v1/instances/${instanceId}/publishes/interests`,
    {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${secretKey}`,
      },
      body: JSON.stringify({
        interests: [input.token],
        apns: {
          aps: {
            alert: {
              title: input.title,
              body: input.body,
            },
            sound: "default",
          },
        },
        fcm: {
          notification: {
            title: input.title,
            body: input.body,
          },
        },
      }),
    },
  );

  const result = await response.json();
  console.log("[Pusher] result:", JSON.stringify(result));

  if (!response.ok) {
    throw new Error(`[Pusher] send_failed: ${JSON.stringify(result)}`);
  }

  return result;
}
