// supabase/functions/receipt-extraction/index.ts
//
// Holds the real Anthropic API key server-side and forwards
// receipt-extraction requests from the TaxÍs iOS client, which now sends
// only its own short-lived Supabase session token — see the security note
// in ReceiptExtractionService.swift. The request/response body is passed
// through to Anthropic unchanged; only the destination and the injected
// credential differ from a direct client -> Anthropic call, so this
// function needs no knowledge of the extraction schema itself.
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

  // This endpoint spends the shared Anthropic budget, so it must never be
  // reachable anonymously — every caller has to present a valid Supabase
  // session, the same short-lived token used for the app's own PostgREST
  // calls (see SupabaseTransactionRepository.swift).
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

  // Passed through verbatim — ReceiptExtractionService's retry/parsing
  // logic reads Anthropic's status codes and body shape directly.
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
