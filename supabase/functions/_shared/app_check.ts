/**
 * Firebase App Check token verification for Supabase Edge Functions.
 *
 * Validates the `X-Firebase-AppCheck` header by calling the Firebase
 * App Check verify endpoint. Rejects requests from non-genuine app clients.
 *
 * Usage in an Edge Function:
 *   const check = await verifyAppCheck(req);
 *   if (!check.ok) return jsonError("app_check", check.message, 403);
 */

type AppCheckResult =
  | { ok: true }
  | { ok: false; message: string };

export async function verifyAppCheck(req: Request): Promise<AppCheckResult> {
  const token = req.headers.get("X-Firebase-AppCheck");

  if (!token) {
    return { ok: false, message: "missing_app_check_token" };
  }

  const projectId = Deno.env.get("FIREBASE_PROJECT_ID");
  if (!projectId) {
    console.error("[AppCheck] FIREBASE_PROJECT_ID not set — skipping verification");
    return { ok: true };
  }

  try {
    const verifyUrl =
      `https://firebaseappcheck.googleapis.com/v1/projects/${projectId}:verifyToken`;

    const res = await fetch(verifyUrl, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ app_check_token: token }),
    });

    if (!res.ok) {
      console.error("[AppCheck] verify failed:", res.status);
      return { ok: false, message: "app_check_verification_failed" };
    }

    return { ok: true };
  } catch (e) {
    console.error("[AppCheck] error:", (e as Error).message);
    return { ok: false, message: "app_check_error" };
  }
}
