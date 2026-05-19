import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const EVENTBRITE_API_BASE = "https://www.eventbriteapi.com/v3";
const SOURCE_TYPE = "eventbrite";
const DEFAULT_STATUS = "live";
const DEFAULT_LIMIT = 25;
const MAX_LIMIT = 100;

type JsonObject = Record<string, unknown>;

type ImportRequest = {
  dryRun: boolean;
  organizationIds: string[];
  organizerIds: string[];
  status: string;
  limit: number;
  after: string | null;
  before: string | null;
};

type NormalizedEvent = {
  externalId: string;
  row: JsonObject;
};

type NormalizedResult =
  | { skipped: false; event: NormalizedEvent }
  | { skipped: true; reason: string; externalId?: string };

type ImportCounts = {
  fetched: number;
  normalized: number;
  skipped: number;
  inserted: number;
  updated: number;
  errors: number;
};

function jsonResponse(body: JsonObject, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

async function readJsonBody(req: Request): Promise<JsonObject> {
  try {
    const body = await req.json();
    return body && typeof body === "object" && !Array.isArray(body)
      ? body as JsonObject
      : {};
  } catch {
    return {};
  }
}

function parseCsvEnv(value: string | undefined): string[] {
  return (value ?? "")
    .split(",")
    .map((item) => item.trim())
    .filter(Boolean);
}

function parseStringArray(value: unknown): string[] {
  if (!Array.isArray(value)) return [];
  return value
    .filter((item): item is string => typeof item === "string")
    .map((item) => item.trim())
    .filter(Boolean);
}

function parseLimit(value: unknown): number {
  const parsed = Number(value ?? DEFAULT_LIMIT);
  if (!Number.isFinite(parsed)) return DEFAULT_LIMIT;
  return Math.min(Math.max(Math.trunc(parsed), 1), MAX_LIMIT);
}

function parseDate(value: unknown): string | null {
  if (typeof value !== "string" || !value.trim()) return null;
  const time = Date.parse(value);
  return Number.isFinite(time) ? new Date(time).toISOString() : null;
}

export function parseImportRequest(
  body: JsonObject,
  env: { organizationIds?: string; organizerIds?: string } = {},
): ImportRequest {
  const requestOrganizationIds = parseStringArray(body.organizationIds);
  const requestOrganizerIds = parseStringArray(body.organizerIds);

  return {
    dryRun: body.dryRun !== false,
    organizationIds: requestOrganizationIds.length > 0
      ? requestOrganizationIds
      : parseCsvEnv(env.organizationIds),
    organizerIds: requestOrganizerIds.length > 0
      ? requestOrganizerIds
      : parseCsvEnv(env.organizerIds),
    status: typeof body.status === "string" && body.status.trim()
      ? body.status.trim()
      : DEFAULT_STATUS,
    limit: parseLimit(body.limit),
    after: parseDate(body.after),
    before: parseDate(body.before),
  };
}

function textField(value: unknown): string | null {
  if (typeof value !== "string") return null;
  const trimmed = value.trim();
  return trimmed ? trimmed : null;
}

function nestedString(object: unknown, path: string[]): string | null {
  let current: unknown = object;
  for (const part of path) {
    if (!current || typeof current !== "object") return null;
    current = (current as JsonObject)[part];
  }
  return textField(current);
}

function numericField(value: unknown): number | null {
  if (typeof value === "number" && Number.isFinite(value)) return value;
  if (typeof value !== "string" || !value.trim()) return null;
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : null;
}

function stripHtml(html: string | null): string | null {
  if (!html) return null;
  const text = html
    .replace(/<script[\s\S]*?<\/script>/gi, " ")
    .replace(/<style[\s\S]*?<\/style>/gi, " ")
    .replace(/<[^>]+>/g, " ")
    .replace(/&nbsp;/g, " ")
    .replace(/&amp;/g, "&")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/\s+/g, " ")
    .trim();
  return text || null;
}

export function classifyEventSubcategory(event: JsonObject): string {
  const title = nestedString(event, ["name", "text"]) ?? "";
  const summary = textField(event.summary) ?? "";
  const description = nestedString(event, ["description", "text"]) ??
    stripHtml(nestedString(event, ["description", "html"])) ?? "";
  const haystack = `${title} ${summary} ${description}`.toLowerCase();

  if (/\b(career|job|hiring|startup|business|entrepreneur|networking|tech|workshop|panel|conference)\b/.test(haystack)) {
    return "career";
  }

  if (/\b(art|arts|culture|music|film|gallery|museum|concert|festival|performance|theatre|theater)\b/.test(haystack)) {
    return "arts_culture";
  }

  return "social";
}

function eventTime(value: string | null): string | null {
  if (!value) return null;
  const time = Date.parse(value);
  return Number.isFinite(time) ? new Date(time).toISOString() : null;
}

function eventStart(event: JsonObject): string | null {
  return eventTime(nestedString(event, ["start", "utc"])) ??
    eventTime(nestedString(event, ["start", "local"]));
}

function eventEnd(event: JsonObject): string | null {
  return eventTime(nestedString(event, ["end", "utc"])) ??
    eventTime(nestedString(event, ["end", "local"]));
}

function eventMatchesDateWindow(event: JsonObject, request: ImportRequest): boolean {
  const startAt = eventStart(event);
  if (!startAt) return false;
  const startTime = Date.parse(startAt);
  if (request.after && startTime < Date.parse(request.after)) return false;
  if (request.before && startTime > Date.parse(request.before)) return false;
  return true;
}

function eventMatchesOrganizer(event: JsonObject, organizerIds: string[]): boolean {
  if (organizerIds.length === 0) return true;
  const organizerId = textField(event.organizer_id) ?? nestedString(event, ["organizer", "id"]);
  return Boolean(organizerId && organizerIds.includes(organizerId));
}

function compactSourceRefs(event: JsonObject, organizationId: string): JsonObject {
  const organizer = event.organizer && typeof event.organizer === "object"
    ? event.organizer as JsonObject
    : {};
  const venue = event.venue && typeof event.venue === "object"
    ? event.venue as JsonObject
    : {};
  const address = venue.address && typeof venue.address === "object"
    ? venue.address as JsonObject
    : {};
  const ticketAvailability = event.ticket_availability &&
      typeof event.ticket_availability === "object"
    ? event.ticket_availability
    : null;

  return {
    provider: SOURCE_TYPE,
    external_id: textField(event.id),
    external_url: textField(event.url),
    organization_id: organizationId,
    organizer_id: textField(event.organizer_id) ?? textField(organizer.id),
    organizer_name: textField(organizer.name),
    venue_id: textField(venue.id),
    venue_name: textField(venue.name),
    venue_region: textField(address.region),
    status: textField(event.status),
    is_free: typeof event.is_free === "boolean" ? event.is_free : null,
    online_event: typeof event.online_event === "boolean" ? event.online_event : null,
    ticket_availability: ticketAvailability,
    start_local: nestedString(event, ["start", "local"]),
    start_timezone: nestedString(event, ["start", "timezone"]),
    end_local: nestedString(event, ["end", "local"]),
    end_timezone: nestedString(event, ["end", "timezone"]),
    raw_imported_at: new Date().toISOString(),
  };
}

export function normalizeEventbriteEvent(
  event: JsonObject,
  organizationId: string,
  request: ImportRequest,
): NormalizedResult {
  const externalId = textField(event.id);
  if (!externalId) return { skipped: true, reason: "missing_external_id" };
  if (!eventMatchesOrganizer(event, request.organizerIds)) {
    return { skipped: true, reason: "organizer_filtered", externalId };
  }
  if (!eventMatchesDateWindow(event, request)) {
    return { skipped: true, reason: "outside_date_window_or_missing_start", externalId };
  }

  const title = nestedString(event, ["name", "text"]);
  if (!title) return { skipped: true, reason: "missing_title", externalId };

  const startAt = eventStart(event);
  if (!startAt) return { skipped: true, reason: "missing_start_at", externalId };

  const venue = event.venue && typeof event.venue === "object"
    ? event.venue as JsonObject
    : {};
  const address = venue.address && typeof venue.address === "object"
    ? venue.address as JsonObject
    : {};
  const summary = textField(event.summary);
  const detailDescription = nestedString(event, ["description", "text"]) ??
    stripHtml(nestedString(event, ["description", "html"]));
  const city = textField(address.city) ?? (event.online_event === true ? "Online" : null);
  const area = textField(address.region) ?? city ?? "Unknown";
  const fullAddress = textField(address.localized_address_display) ??
    textField(address.localized_multi_line_address_display) ??
    textField(address.address_1);

  const row: JsonObject = {
    title,
    type: "event",
    category: "events",
    subcategories: [classifyEventSubcategory(event)],
    area,
    city,
    address: fullAddress,
    lat: numericField(venue.latitude),
    lng: numericField(venue.longitude),
    budget_level: "any",
    vibe_tags: [],
    activity_tags: [],
    short_description: summary,
    detail_description: detailDescription,
    image_url: nestedString(event, ["logo", "original", "url"]) ??
      nestedString(event, ["logo", "url"]),
    source_type: SOURCE_TYPE,
    source_refs: compactSourceRefs(event, organizationId),
    quality_score: 0,
    korean_community_fit: 0,
    is_active: false,
    is_approved: false,
    view_count: 0,
    save_count: 0,
    review_count: 0,
    average_rating: 0,
    start_at: startAt,
    end_at: eventEnd(event),
  };

  return { skipped: false, event: { externalId, row } };
}

export function buildUpdateRow(row: JsonObject): JsonObject {
  const {
    category,
    subcategories,
    vibe_tags,
    activity_tags,
    quality_score,
    korean_community_fit,
    is_active,
    is_approved,
    view_count,
    save_count,
    review_count,
    average_rating,
    short_description,
    detail_description,
    ...sourceOwnedFields
  } = row;

  return sourceOwnedFields;
}

function increment(object: Record<string, number>, key: string) {
  object[key] = (object[key] ?? 0) + 1;
}

async function fetchOrganizationEvents(params: {
  token: string;
  organizationId: string;
  request: ImportRequest;
  limit: number;
}): Promise<JsonObject[]> {
  const events: JsonObject[] = [];
  let continuation: string | null = null;

  while (events.length < params.limit) {
    const url = new URL(`${EVENTBRITE_API_BASE}/organizations/${encodeURIComponent(params.organizationId)}/events/`);
    url.searchParams.set("status", params.request.status);
    url.searchParams.set("expand", "venue,organizer,ticket_availability");
    url.searchParams.set("page_size", String(Math.min(50, params.limit)));
    if (params.request.after) {
      url.searchParams.set("start_date.range_start", params.request.after);
    }
    if (params.request.before) {
      url.searchParams.set("start_date.range_end", params.request.before);
    }
    if (continuation) url.searchParams.set("continuation", continuation);

    const response = await fetch(url, {
      headers: { Authorization: `Bearer ${params.token}` },
    });

    if (!response.ok) {
      throw new Error(`Eventbrite organization ${params.organizationId} request failed: ${response.status}`);
    }

    const data = await response.json();
    if (Array.isArray(data?.events)) {
      events.push(...data.events.filter((event: unknown): event is JsonObject =>
        Boolean(event && typeof event === "object" && !Array.isArray(event))
      ));
    }

    const nextContinuation = textField(data?.pagination?.continuation);
    const hasMoreItems = data?.pagination?.has_more_items === true;
    if (!hasMoreItems || !nextContinuation) break;
    continuation = nextContinuation;
  }

  return events.slice(0, params.limit);
}

async function insertImportLog(
  supabase: ReturnType<typeof createClient>,
  request: ImportRequest,
): Promise<string | null> {
  if (request.dryRun) return null;
  const { data, error } = await supabase
    .from("api_import_logs")
    .insert({
      source_type: SOURCE_TYPE,
      status: "running",
      inserted_count: 0,
      updated_count: 0,
      failed_count: 0,
      metadata: {
        dry_run: false,
        organization_ids: request.organizationIds,
        organizer_ids: request.organizerIds,
      },
    })
    .select("id")
    .single();

  if (error) throw error;
  return data?.id ?? null;
}

async function finishImportLog(
  supabase: ReturnType<typeof createClient>,
  logId: string | null,
  status: "succeeded" | "failed" | "partial",
  request: ImportRequest,
  counts: ImportCounts,
  skippedReasons: Record<string, number>,
  errorSummary?: string,
) {
  if (!logId) return;
  const { error } = await supabase
    .from("api_import_logs")
    .update({
      status,
      inserted_count: counts.inserted,
      updated_count: counts.updated,
      failed_count: counts.errors,
      error_message: errorSummary ?? null,
      finished_at: new Date().toISOString(),
      metadata: {
        dry_run: false,
        organization_ids: request.organizationIds,
        organizer_ids: request.organizerIds,
        fetched_count: counts.fetched,
        normalized_count: counts.normalized,
        skipped_count: counts.skipped,
        error_count: counts.errors,
        skipped_reasons: skippedReasons,
      },
    })
    .eq("id", logId);

  if (error) throw error;
}

export async function findExistingEventbriteRow(
  supabase: ReturnType<typeof createClient>,
  externalId: string,
): Promise<{ id: string } | null> {
  const { data, error } = await supabase
    .from("content_items")
    .select("id")
    .eq("source_type", SOURCE_TYPE)
    .filter("source_refs->>external_id", "eq", externalId)
    .limit(1);

  if (error) throw error;
  return data?.[0] ?? null;
}

export async function upsertRows(
  supabase: ReturnType<typeof createClient>,
  rows: NormalizedEvent[],
): Promise<{ inserted: number; updated: number }> {
  let inserted = 0;
  let updated = 0;

  for (const event of rows) {
    const existing = await findExistingEventbriteRow(supabase, event.externalId);
    if (existing) {
      const { error } = await supabase
        .from("content_items")
        .update(buildUpdateRow(event.row))
        .eq("id", existing.id);
      if (error) throw error;
      updated += 1;
    } else {
      const { error } = await supabase
        .from("content_items")
        .insert(event.row);
      if (error) throw error;
      inserted += 1;
    }
  }

  return { inserted, updated };
}

export async function handler(req: Request): Promise<Response> {
  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  const body = await readJsonBody(req);
  const request = parseImportRequest(body, {
    organizationIds: Deno.env.get("EVENTBRITE_ORGANIZATION_IDS"),
    organizerIds: Deno.env.get("EVENTBRITE_ORGANIZER_IDS"),
  });

  const token = Deno.env.get("EVENTBRITE_OAUTH_TOKEN")?.trim();
  if (!token) {
    return jsonResponse({ error: "EVENTBRITE_OAUTH_TOKEN is not configured" }, 500);
  }

  if (request.organizationIds.length === 0) {
    return jsonResponse({ error: "At least one Eventbrite organization id is required" }, 400);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!request.dryRun && (!supabaseUrl || !serviceRoleKey)) {
    return jsonResponse({ error: "Supabase service role environment is not configured" }, 500);
  }

  const counts: ImportCounts = {
    fetched: 0,
    normalized: 0,
    skipped: 0,
    inserted: 0,
    updated: 0,
    errors: 0,
  };
  const skippedReasons: Record<string, number> = {};
  const errors: string[] = [];
  const normalizedRows: NormalizedEvent[] = [];

  const supabase = !request.dryRun
    ? createClient(supabaseUrl!, serviceRoleKey!)
    : null;
  let logId: string | null = null;

  try {
    if (supabase) {
      logId = await insertImportLog(supabase, request);
    }

    for (const organizationId of request.organizationIds) {
      if (counts.fetched >= request.limit) break;
      try {
        const events = await fetchOrganizationEvents({
          token,
          organizationId,
          request,
          limit: request.limit - counts.fetched,
        });
        counts.fetched += events.length;
        for (const event of events) {
          const normalized = normalizeEventbriteEvent(event, organizationId, request);
          if (normalized.skipped) {
            counts.skipped += 1;
            increment(skippedReasons, normalized.reason);
          } else {
            counts.normalized += 1;
            normalizedRows.push(normalized.event);
          }
        }
      } catch (error) {
        counts.errors += 1;
        errors.push(error instanceof Error ? error.message : String(error));
      }
    }

    if (!request.dryRun && supabase) {
      const result = await upsertRows(supabase, normalizedRows);
      counts.inserted = result.inserted;
      counts.updated = result.updated;
      await finishImportLog(
        supabase,
        logId,
        counts.errors > 0 ? "partial" : "succeeded",
        request,
        counts,
        skippedReasons,
        errors[0],
      );
    }

    return jsonResponse({
      source: SOURCE_TYPE,
      dryRun: request.dryRun,
      counts,
      skippedReasons,
      errors,
      rows: request.dryRun ? normalizedRows.map((event) => event.row) : undefined,
    });
  } catch (error) {
    counts.errors += 1;
    const message = error instanceof Error ? error.message : String(error);
    if (supabase) {
      await finishImportLog(
        supabase,
        logId,
        "failed",
        request,
        counts,
        skippedReasons,
        message,
      );
    }
    console.warn(`Eventbrite import failed: ${message}`);
    return jsonResponse({ error: "Eventbrite import failed", details: message }, 500);
  }
}

if (import.meta.main) {
  serve(handler);
}
