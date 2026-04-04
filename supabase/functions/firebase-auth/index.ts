import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { cert, getApps, initializeApp } from "npm:firebase-admin/app";
import { getAuth } from "npm:firebase-admin/auth";

import { json, jsonError, preflight } from "../_shared/cors.ts";

function requireEnv(name: string): string {
  const v = Deno.env.get(name);
  if (!v?.trim()) throw new Error(`Missing required secret: ${name}`);
  return v.trim();
}

function initFirebaseAdmin(): void {
  if (getApps().length > 0) return;
  const raw = requireEnv("FIREBASE_SERVICE_ACCOUNT_JSON");
  const credentials = JSON.parse(raw);
  initializeApp({ credential: cert(credentials) });
}

function normalizePhone(phone: string): string {
  const digits = phone.replace(/\D/g, "");
  if (digits.length === 0) return phone.trim();
  return `+${digits}`;
}

/** Admin generateLink(magiclink) requires an email on the user. */
function syntheticEmailFromPhone(phone: string): string {
  const digits = phone.replace(/\D/g, "");
  return `${digits}@phone.laundrypro.internal`;
}

async function findUserByPhone(
  admin: ReturnType<typeof createClient>,
  phone: string,
) {
  const normalized = normalizePhone(phone);
  let page = 1;
  const maxPages = 200;
  while (page <= maxPages) {
    const { data, error } = await admin.auth.admin.listUsers({
      page,
      perPage: 1000,
    });
    if (error) throw error;
    const found = data.users.find((u) =>
      u.phone && normalizePhone(u.phone) === normalized
    );
    if (found) return found;
    if (data.users.length < 1000) return null;
    page++;
  }
  return null;
}

/**
 * Resolve Supabase Auth user by phone; create if missing.
 * Ensures an email exists so admin.generateLink({ type: 'magiclink' }) works.
 * (There is no public auth.admin.createSession in supabase-js; session comes from verify.)
 */
async function ensureUserForSession(
  admin: ReturnType<typeof createClient>,
  phone: string,
) {
  const syntheticEmail = syntheticEmailFromPhone(phone);
  let user = await findUserByPhone(admin, phone);

  if (!user) {
    const { data, error } = await admin.auth.admin.createUser({
      phone,
      phone_confirm: true,
    });
    if (error) {
      const msg = error.message ?? "";
      if (/already|registered|exists|duplicate/i.test(msg)) {
        user = await findUserByPhone(admin, phone);
      } else {
        throw error;
      }
    } else {
      user = data.user!;
    }
  }

  if (!user) {
    throw new Error("Could not resolve Supabase auth user for phone");
  }

  const emailForLink = user.email ?? syntheticEmail;
  if (!user.email) {
    const { data, error } = await admin.auth.admin.updateUserById(user.id, {
      email: syntheticEmail,
      email_confirm: true,
    });
    if (error) throw error;
    user = data.user!;
  }

  return { emailForLink: user.email ?? emailForLink };
}

/** Exchange magiclink hashed_token for a real session (access + refresh tokens). */
async function sessionFromMagicLink(
  supabaseUrl: string,
  anonKey: string,
  hashedToken: string,
): Promise<{ access_token: string; refresh_token: string }> {
  const verifyRes = await fetch(`${supabaseUrl}/auth/v1/verify`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      apikey: anonKey,
      Authorization: `Bearer ${anonKey}`,
    },
    body: JSON.stringify({
      type: "magiclink",
      token_hash: hashedToken,
    }),
  });

  const verifyJson = await verifyRes.json().catch(() => ({}));
  if (!verifyRes.ok) {
    console.error("verify failed", verifyRes.status, verifyJson);
    const msg = typeof verifyJson?.msg === "string"
      ? verifyJson.msg
      : "Supabase verify failed";
    throw new Error(msg);
  }

  const access_token = verifyJson.access_token as string | undefined;
  const refresh_token = verifyJson.refresh_token as string | undefined;
  if (!refresh_token?.length) {
    throw new Error("No refresh_token in verify response");
  }
  return {
    access_token: access_token ?? "",
    refresh_token,
  };
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return preflight();

  let supabaseUrl: string;
  let serviceKey: string;
  let anonKey: string;
  let firebaseProjectId: string;
  try {
    supabaseUrl = requireEnv("SUPABASE_URL");
    serviceKey = requireEnv("SUPABASE_SERVICE_ROLE_KEY");
    anonKey = requireEnv("SUPABASE_ANON_KEY");
    firebaseProjectId = requireEnv("FIREBASE_PROJECT_ID");
  } catch (e) {
    const message = e instanceof Error ? e.message : "config";
    return jsonError("config", message, 500);
  }

  let body: { idToken?: string; phone?: string };
  try {
    body = await req.json();
  } catch {
    return jsonError("bad_request", "Invalid JSON body", 400);
  }

  const idToken = body.idToken?.trim();
  const phone = body.phone?.trim();
  if (!idToken || !phone) {
    return jsonError("bad_request", "idToken and phone are required", 400);
  }

  try {
    initFirebaseAdmin();
    const decoded = await getAuth().verifyIdToken(idToken, true);
    if (decoded.aud !== firebaseProjectId) {
      return jsonError("invalid_token", "Firebase token audience mismatch", 401);
    }
    const tokenPhone = decoded.phone_number;
    if (!tokenPhone || normalizePhone(tokenPhone) !== normalizePhone(phone)) {
      return jsonError(
        "phone_mismatch",
        "Phone does not match Firebase token",
        403,
      );
    }

    const admin = createClient(supabaseUrl, serviceKey, {
      auth: { autoRefreshToken: false, persistSession: false },
    });

    const { emailForLink } = await ensureUserForSession(admin, phone);

    const { data: linkData, error: linkError } = await admin.auth.admin
      .generateLink({
        type: "magiclink",
        email: emailForLink,
      });
    if (linkError) throw linkError;

    const hashedToken = linkData?.properties?.hashed_token;
    if (!hashedToken) {
      return jsonError(
        "link_failed",
        "generateLink did not return hashed_token",
        500,
      );
    }

    const tokens = await sessionFromMagicLink(
      supabaseUrl,
      anonKey,
      hashedToken,
    );

    return json({
      access_token: tokens.access_token,
      refresh_token: tokens.refresh_token,
    });
  } catch (e) {
    console.error(e);
    const message = e instanceof Error ? e.message : "internal_error";
    return jsonError("internal", message, 500);
  }
});
