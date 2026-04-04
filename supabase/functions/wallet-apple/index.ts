import { PKPass } from "npm:passkit-generator@3.2.0";
import { supabaseAdmin } from "../_shared/supabase_admin.ts";

type Json =
  | null
  | boolean
  | number
  | string
  | Json[]
  | { [key: string]: Json };

function json(status: number, body: Json) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json; charset=utf-8" },
  });
}

function getEnv(name: string) {
  const v = Deno.env.get(name);
  if (!v) throw new Error(`missing_env:${name}`);
  return v;
}

function envToBytes(name: string): Uint8Array {
  const v = getEnv(name).trim();
  if (v.startsWith("-----BEGIN")) {
    return new TextEncoder().encode(v.replaceAll("\\n", "\n"));
  }
  const raw = atob(v);
  return new TextEncoder().encode(raw);
}

const ONE_BY_ONE_PNG_BASE64 =
  "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO9WZ2kAAAAASUVORK5CYII=";

function oneByOnePngBytes(): Uint8Array {
  const raw = atob(ONE_BY_ONE_PNG_BASE64);
  return new Uint8Array([...raw].map((c) => c.charCodeAt(0)));
}

async function loadPassModel(): Promise<Record<string, unknown>> {
  const base = new URL("./pass/pass.json", import.meta.url);
  const txt = await Deno.readTextFile(base);
  return JSON.parse(txt) as Record<string, unknown>;
}

Deno.serve(async (req) => {
  try {
    if (req.method !== "GET") return json(405, { error: "method_not_allowed" });

    const url = new URL(req.url);
    const userId = url.searchParams.get("user_id")?.trim() ?? "";
    if (!userId) return json(400, { error: "missing_user_id" });

    const sb = supabaseAdmin();
    const { data: user, error } = await sb
      .from("users")
      .select("id,name,points")
      .eq("id", userId)
      .maybeSingle();

    if (error) throw error;
    if (!user) return json(404, { error: "user_not_found" });

    const passTypeIdentifier = getEnv("APPLE_PASS_TYPE_ID");
    const teamIdentifier = getEnv("APPLE_TEAM_ID");

    const model = await loadPassModel();
    model.passTypeIdentifier = passTypeIdentifier;
    model.teamIdentifier = teamIdentifier;
    model.serialNumber = user.id;

    // storeCard fields
    const storeCard = (model.storeCard ?? {}) as Record<string, unknown>;
    const primaryFields = (storeCard.primaryFields ?? []) as unknown[];
    const secondaryFields = (storeCard.secondaryFields ?? []) as unknown[];

    if (primaryFields[0] && typeof primaryFields[0] === "object") {
      (primaryFields[0] as Record<string, unknown>).value = user.name ?? "";
    }
    if (secondaryFields[0] && typeof secondaryFields[0] === "object") {
      (secondaryFields[0] as Record<string, unknown>).value = String(user.points ?? 0);
    }
    storeCard.primaryFields = primaryFields;
    storeCard.secondaryFields = secondaryFields;
    model.storeCard = storeCard;

    const pass = await PKPass.from(
      {
        model,
        certificates: {
          wwdr: envToBytes("APPLE_WWDR_CERT"),
          signerCert: envToBytes("APPLE_SIGNER_CERT"),
          signerKey: envToBytes("APPLE_SIGNER_KEY"),
          signerKeyPassphrase: getEnv("APPLE_SIGNER_KEY_PASSPHRASE"),
        },
      },
      {
        "icon.png": oneByOnePngBytes(),
        "icon@2x.png": oneByOnePngBytes(),
        "logo.png": oneByOnePngBytes(),
        "logo@2x.png": oneByOnePngBytes(),
      },
    );

    pass.setBarcodes({
      format: "PKBarcodeFormatQR",
      message: user.id,
      messageEncoding: "iso-8859-1",
    });

    const buf = pass.getAsBuffer();

    return new Response(buf, {
      status: 200,
      headers: {
        "content-type": "application/vnd.apple.pkpass",
        "content-disposition": `attachment; filename=\"${user.id}.pkpass\"`,
        "cache-control": "no-store",
      },
    });
  } catch (e) {
    return json(500, { error: "internal_error" });
  }
});

