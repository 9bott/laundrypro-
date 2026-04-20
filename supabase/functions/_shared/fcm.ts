import { initializeApp, cert, getApps } from "https://esm.sh/firebase-admin@13.5.0/app";
import { getMessaging } from "https://esm.sh/firebase-admin@13.5.0/messaging";

function requiredEnv(name: string): string {
  const v = Deno.env.get(name);
  if (!v) throw new Error(`[fcm] missing secret: ${name}`);
  return v;
}

function initAdminOnce() {
  if (getApps().length) return;
  const saJson = Deno.env.get("FIREBASE_SERVICE_ACCOUNT_JSON");
  if (saJson && saJson.trim().length) {
    const parsed = JSON.parse(saJson) as {
      project_id: string;
      client_email: string;
      private_key: string;
    };
    initializeApp({
      credential: cert({
        projectId: parsed.project_id,
        clientEmail: parsed.client_email,
        privateKey: parsed.private_key,
      }),
    });
    return;
  }

  // Fallback secrets (explicit fields).
  const projectId = requiredEnv("FIREBASE_PROJECT_ID");
  const clientEmail = requiredEnv("FIREBASE_CLIENT_EMAIL");
  const privateKeyRaw = requiredEnv("FIREBASE_PRIVATE_KEY");
  const privateKey = privateKeyRaw.replace(/\\n/g, "\n");

  initializeApp({
    credential: cert({ projectId, clientEmail, privateKey }),
  });
}

export async function sendFCMNotification(input: {
  token: string;
  title: string;
  body: string;
  data?: Record<string, string>;
}): Promise<void> {
  if (!input.token) return;
  initAdminOnce();
  const messaging = getMessaging();

  await messaging.send({
    token: input.token,
    notification: {
      title: input.title,
      body: input.body,
    },
    data: input.data,
  });
}

