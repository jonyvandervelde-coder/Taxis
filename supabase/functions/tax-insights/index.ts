// supabase/functions/tax-insights/index.ts
//
// Same proxy pattern as receipt-extraction/index.ts: holds the real
// Anthropic key server-side, requires a valid Supabase session, forwards
// the request body to Anthropic unchanged. This endpoint has no
// knowledge of tax rules itself — all of that lives in
// TaxInsightsService.swift's system prompt on the client, which builds
// the request this function forwards. Kept as a thin, reusable proxy
// rather than duplicating the receipt-extraction function, since the
// only difference between the two calls is the request body.
//
// Required secrets (set with `supabase secrets set`):
//   ANTHROPIC_API_KEY   — the real Anthropic key, never shipped to the client
// Available automatically in every Edge Function:
//   SUPABASE_URL, SUPABASE_ANON_KEY

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const ANTHROPIC_API_KEY = Deno.env.get("ANTHROPIC_API_KEY");
const ANTHROPIC_VERSION = "2023-06-01";
const ANTHROPIC_URL = "https://api.anthropic.com/v1/messages";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed." }, 405);
  }
  if (!ANTHROPIC_API_KEY) {
    return jsonResponse({ error: "ANTHROPIC_API_KEY is not configured on the server." }, 500);
  }

  const authHeader = req.headers.get("Authorization");
  if (!authHeader?.startsWith("Bearer ")) {
    return jsonResponse({ error: "Missing bearer token." }, 401);
  }
  const accessToken = authHeader.slice("Bearer ".length);

  const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
  const { data: userData, error: userError } = await supabase.auth.getUser(accessToken);
  if (userError || !userData.user) {
    return jsonResponse({ error: "Invalid or expired session." }, 401);
  }

  let body: unknown;
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: "Request body must be JSON." }, 400);
  }

  const anthropicResponse = await fetch(ANTHROPIC_URL, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "x-api-key": ANTHROPIC_API_KEY,
      "anthropic-version": ANTHROPIC_VERSION,
    },
    body: JSON.stringify(body),
  });

  const responseBody = await anthropicResponse.text();
  return new Response(responseBody, {
    status: anthropicResponse.status,
    headers: { "Content-Type": "application/json" },
  });
});

function jsonResponse(body: Record<string, unknown>, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}
