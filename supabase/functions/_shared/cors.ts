export const corsHeaders: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-internal-secret",
  "Access-Control-Allow-Methods": "POST, GET, OPTIONS",
};

export function preflight(): Response {
  return new Response("ok", { headers: corsHeaders });
}

export function json(
  body: unknown,
  status = 200,
  extraHeaders?: Record<string, string>,
): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
      ...extraHeaders,
    },
  });
}

export function jsonError(
  code: string,
  message: string,
  status = 400,
  extra?: Record<string, unknown>,
): Response {
  return json({ success: false, error: code, message, ...extra }, status);
}
