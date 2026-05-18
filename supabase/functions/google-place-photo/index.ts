import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

import { createClient } from "npm:@supabase/supabase-js@2";

function jsonResponse(body: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

async function readRequestParams(req: Request): Promise<Record<string, unknown>> {
  if (req.method === "GET") {
    const url = new URL(req.url);
    return Object.fromEntries(url.searchParams.entries());
  }

  try {
    const body = await req.json();
    return body && typeof body === "object" && !Array.isArray(body)
      ? body as Record<string, unknown>
      : {};
  } catch {
    return {};
  }
}

function integerParam(value: unknown, fallback: number): number {
  const parsed = Number(value ?? fallback);
  if (!Number.isFinite(parsed)) return fallback;
  return Math.min(Math.max(Math.trunc(parsed), 1), 4800);
}

async function handler(req: Request): Promise<Response> {
  if (req.method !== "GET" && req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    return jsonResponse({ error: "Missing Authorization header" }, 401);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY");
  if (!supabaseUrl || !supabaseAnonKey) {
    return jsonResponse({ error: "Supabase environment is not configured" }, 500);
  }

  const supabase = createClient(supabaseUrl, supabaseAnonKey, {
    global: { headers: { Authorization: authHeader } },
  });
  const {
    data: { user },
    error: userError,
  } = await supabase.auth.getUser();

  if (userError || !user) {
    return jsonResponse({ error: "Unauthorized" }, 401);
  }

  const params = await readRequestParams(req);
  const photoName = typeof params.photoName === "string"
    ? params.photoName.trim()
    : "";

  if (!photoName) {
    return jsonResponse({ error: "photoName is required" }, 400);
  }

  if (!photoName.startsWith("places/") || !photoName.includes("/photos/")) {
    return jsonResponse({ error: "Invalid Google Places photo resource name" }, 400);
  }

  const googleApiKey = Deno.env.get("GOOGLE_PLACES_API_KEY")?.trim();
  if (!googleApiKey) {
    return jsonResponse({ error: "GOOGLE_PLACES_API_KEY is not configured" }, 500);
  }

  const maxWidthPx = integerParam(params.maxWidthPx, 1200);
  const maxHeightPx = integerParam(params.maxHeightPx, 800);
  const url = new URL(`https://places.googleapis.com/v1/${photoName}/media`);
  url.searchParams.set("maxWidthPx", String(maxWidthPx));
  url.searchParams.set("maxHeightPx", String(maxHeightPx));
  url.searchParams.set("skipHttpRedirect", "true");
  url.searchParams.set("key", googleApiKey);

  let response: Response;
  try {
    response = await fetch(url);
  } catch {
    console.warn("Google Place Photo request failed before receiving a response");
    return jsonResponse({ error: "Google Place Photo request failed" }, 502);
  }

  if (!response.ok) {
    console.warn(`Google Place Photo request failed: ${response.status}`);
    return jsonResponse({ error: "Google Place Photo request failed" }, 502);
  }

  const data = await response.json();
  return jsonResponse({
    name: typeof data?.name === "string" ? data.name : null,
    photoUri: typeof data?.photoUri === "string" ? data.photoUri : null,
  });
}

if (import.meta.main) {
  serve(handler);
}
