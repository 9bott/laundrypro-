function base64UrlEncode(data: string | Uint8Array): string {
  const bytes = typeof data === "string" ? new TextEncoder().encode(data) : data;
  let binary = "";
  for (let i = 0; i < bytes.length; i++) binary += String.fromCharCode(bytes[i]);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/g, "");
}

function pemToPkcs8Der(pem: string): Uint8Array {
  const b64 = pem
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replace(/\s+/g, "");
  const raw = atob(b64);
  const out = new Uint8Array(raw.length);
  for (let i = 0; i < raw.length; i++) out[i] = raw.charCodeAt(i);
  return out;
}

type ServiceAccount = {
  project_id: string;
  client_email: string;
  private_key: string;
};

async function getGoogleAccessToken(sa: ServiceAccount): Promise<string> {
  const now = Math.floor(Date.now() / 1000);

  const header = { alg: "RS256", typ: "JWT" };
  const payload = {
    iss: sa.client_email,
    sub: sa.client_email,
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
  };

  const encodedHeader = base64UrlEncode(JSON.stringify(header));
  const encodedPayload = base64UrlEncode(JSON.stringify(payload));
  const signingInput = `${encodedHeader}.${encodedPayload}`;

  const cryptoKey = await crypto.subtle.importKey(
    "pkcs8",
    pemToPkcs8Der(sa.private_key),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );

  const sig = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    cryptoKey,
    new TextEncoder().encode(signingInput),
  );

  const jwt = `${signingInput}.${base64UrlEncode(new Uint8Array(sig))}`;

  const tokenResponse = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });

  const tokenJson = await tokenResponse.json();
  if (!tokenResponse.ok) {
    throw new Error(`[FCM] oauth_failed ${tokenResponse.status}: ${JSON.stringify(tokenJson)}`);
  }
  const accessToken = tokenJson.access_token as string | undefined;
  if (!accessToken) throw new Error("[FCM] oauth_missing_access_token");
  return accessToken;
}

export async function sendFCMNotification(input: {
  token: string;
  title: string;
  body: string;
  data?: Record<string, string>;
}): Promise<unknown> {
  if (!input.token) return null;

  const raw = Deno.env.get("FIREBASE_SERVICE_ACCOUNT_JSON");
  if (!raw) throw new Error("[FCM] missing secret: FIREBASE_SERVICE_ACCOUNT_JSON");
  const sa = JSON.parse(raw) as Partial<ServiceAccount>;
  if (!sa.project_id || !sa.client_email || !sa.private_key) {
    throw new Error("[FCM] invalid FIREBASE_SERVICE_ACCOUNT_JSON");
  }

  const accessToken = await getGoogleAccessToken(sa as ServiceAccount);

  const fcmResponse = await fetch(
    `https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`,
    {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${accessToken}`,
      },
      body: JSON.stringify({
        message: {
          token: input.token,
          notification: { title: input.title, body: input.body },
          data: input.data ?? {},
          apns: {
            payload: {
              aps: {
                sound: "default",
                badge: 1,
              },
            },
          },
          android: {
            priority: "high",
          },
        },
      }),
    },
  );

  const result = await fcmResponse.json();
  console.log("[FCM] result:", JSON.stringify(result));
  if (!fcmResponse.ok) {
    throw new Error(`[FCM] send_failed ${fcmResponse.status}: ${JSON.stringify(result)}`);
  }
  return result;
}

