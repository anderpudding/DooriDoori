import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const GOOGLE_PLACE_DETAILS_BASE = "https://places.googleapis.com/v1/places";
const PLACE_DETAILS_FIELD_MASK = [
  "id",
  "displayName",
  "formattedAddress",
  "location",
  "rating",
  "userRatingCount",
  "regularOpeningHours",
  "currentOpeningHours",
  "photos",
  "googleMapsUri",
  "websiteUri",
  "nationalPhoneNumber",
  "businessStatus",
].join(",");

type ContentItemRow = {
  id: string;
  type: string | null;
  source_refs: Record<string, unknown> | null;
};

function jsonResponse(body: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

async function readJsonBody(req: Request): Promise<Record<string, unknown>> {
  try {
    const body = await req.json();
    return body && typeof body === "object" && !Array.isArray(body)
      ? body as Record<string, unknown>
      : {};
  } catch {
    return {};
  }
}

function googlePlaceIdFrom(row: ContentItemRow): string | null {
  const value = row.source_refs?.google_place_id;
  return typeof value === "string" && value.trim() ? value.trim() : null;
}

function normalizePlaceDetails(place: any): Record<string, unknown> {
  return {
    placeId: typeof place?.id === "string" ? place.id : null,
    displayName: typeof place?.displayName?.text === "string"
      ? place.displayName.text
      : null,
    formattedAddress: typeof place?.formattedAddress === "string"
      ? place.formattedAddress
      : null,
    latitude: typeof place?.location?.latitude === "number"
      ? place.location.latitude
      : null,
    longitude: typeof place?.location?.longitude === "number"
      ? place.location.longitude
      : null,
    rating: typeof place?.rating === "number" ? place.rating : null,
    userRatingCount: typeof place?.userRatingCount === "number"
      ? place.userRatingCount
      : null,
    regularOpeningHours: place?.regularOpeningHours ?? null,
    currentOpeningHours: place?.currentOpeningHours ?? null,
    googleMapsUri: typeof place?.googleMapsUri === "string"
      ? place.googleMapsUri
      : null,
    websiteUri: typeof place?.websiteUri === "string" ? place.websiteUri : null,
    nationalPhoneNumber: typeof place?.nationalPhoneNumber === "string"
      ? place.nationalPhoneNumber
      : null,
    businessStatus: typeof place?.businessStatus === "string"
      ? place.businessStatus
      : null,
    photos: Array.isArray(place?.photos)
      ? place.photos.map((photo: any) => ({
        name: typeof photo?.name === "string" ? photo.name : null,
        widthPx: typeof photo?.widthPx === "number" ? photo.widthPx : null,
        heightPx: typeof photo?.heightPx === "number" ? photo.heightPx : null,
        authorAttributions: Array.isArray(photo?.authorAttributions)
          ? photo.authorAttributions
          : [],
      })).filter((photo: any) => typeof photo.name === "string")
      : [],
  };
}

async function handler(req: Request): Promise<Response> {
  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    return jsonResponse({ error: "Missing Authorization header" }, 401);
  }

  const body = await readJsonBody(req);
  const contentItemId = typeof body.contentItemId === "string"
    ? body.contentItemId.trim()
    : "";

  if (!contentItemId) {
    return jsonResponse({ error: "contentItemId is required" }, 400);
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

  const { data: item, error: itemError } = await supabase
    .from("content_items")
    .select("id,type,source_refs")
    .eq("id", contentItemId)
    .maybeSingle();

  if (itemError) {
    return jsonResponse({ error: "Unable to load content item" }, 500);
  }

  if (!item) {
    return jsonResponse({ error: "Content item not found" }, 404);
  }

  if ((item as ContentItemRow).type !== "place") {
    return jsonResponse({ error: "Google Place Details are only available for place content items" }, 400);
  }

  const googlePlaceId = googlePlaceIdFrom(item as ContentItemRow);
  if (!googlePlaceId) {
    return jsonResponse({ error: "google_place_id is missing for this content item" }, 400);
  }

  const googleApiKey = Deno.env.get("GOOGLE_PLACES_API_KEY")?.trim();
  if (!googleApiKey) {
    return jsonResponse({ error: "GOOGLE_PLACES_API_KEY is not configured" }, 500);
  }

  let response: Response;
  try {
    response = await fetch(
      `${GOOGLE_PLACE_DETAILS_BASE}/${encodeURIComponent(googlePlaceId)}`,
      {
        method: "GET",
        headers: {
          "Content-Type": "application/json",
          "X-Goog-Api-Key": googleApiKey,
          "X-Goog-FieldMask": PLACE_DETAILS_FIELD_MASK,
        },
      },
    );
  } catch {
    console.warn("Google Place Details request failed before receiving a response");
    return jsonResponse({ error: "Google Place Details request failed" }, 502);
  }

  if (!response.ok) {
    console.warn(`Google Place Details request failed: ${response.status}`);
    return jsonResponse({ error: "Google Place Details request failed" }, 502);
  }

  const place = await response.json();
  return jsonResponse(normalizePlaceDetails(place));
}

if (import.meta.main) {
  serve(handler);
}
