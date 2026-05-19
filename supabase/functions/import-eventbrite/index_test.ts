import {
  assertEquals,
  assertExists,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  buildUpdateRow,
  classifyEventSubcategory,
  handler,
  normalizeEventbriteEvent,
  parseImportRequest,
  upsertRows,
} from "./index.ts";

const baseRequest = parseImportRequest({
  dryRun: true,
  organizationIds: ["org-1"],
  limit: 10,
  status: "live",
});

function event(overrides: Record<string, unknown> = {}) {
  return {
    id: "event-1",
    name: { text: "Korean Community Social" },
    summary: "Meet new people in Vancouver.",
    description: { text: "A friendly social night." },
    url: "https://eventbrite.com/e/event-1",
    start: { utc: "2026-06-01T02:00:00Z", local: "2026-05-31T19:00:00", timezone: "America/Vancouver" },
    end: { utc: "2026-06-01T04:00:00Z", local: "2026-05-31T21:00:00", timezone: "America/Vancouver" },
    logo: { original: { url: "https://example.com/logo.jpg" } },
    organizer_id: "organizer-1",
    organizer: { id: "organizer-1", name: "Doori Events" },
    venue: {
      latitude: "49.2827",
      longitude: "-123.1207",
      address: {
        city: "Vancouver",
        region: "BC",
        localized_address_display: "123 Main St, Vancouver, BC",
      },
    },
    is_free: true,
    status: "live",
    online_event: false,
    ...overrides,
  };
}

Deno.test("missing env organization ids are preserved as controlled empty state", () => {
  const request = parseImportRequest({ dryRun: true }, {});
  assertEquals(request.organizationIds, []);
});

Deno.test("missing EVENTBRITE_OAUTH_TOKEN returns controlled error", async () => {
  const previousToken = Deno.env.get("EVENTBRITE_OAUTH_TOKEN");
  const previousOrganizations = Deno.env.get("EVENTBRITE_ORGANIZATION_IDS");
  Deno.env.delete("EVENTBRITE_OAUTH_TOKEN");
  Deno.env.set("EVENTBRITE_ORGANIZATION_IDS", "org-1");

  const response = await handler(new Request("http://localhost", {
    method: "POST",
    body: JSON.stringify({ dryRun: true }),
  }));
  const body = await response.json();

  assertEquals(response.status, 500);
  assertEquals(body.error, "EVENTBRITE_OAUTH_TOKEN is not configured");

  if (previousToken) Deno.env.set("EVENTBRITE_OAUTH_TOKEN", previousToken);
  if (previousOrganizations) {
    Deno.env.set("EVENTBRITE_ORGANIZATION_IDS", previousOrganizations);
  } else {
    Deno.env.delete("EVENTBRITE_ORGANIZATION_IDS");
  }
});

Deno.test("missing organization ids returns controlled error", async () => {
  const previousToken = Deno.env.get("EVENTBRITE_OAUTH_TOKEN");
  const previousOrganizations = Deno.env.get("EVENTBRITE_ORGANIZATION_IDS");
  Deno.env.set("EVENTBRITE_OAUTH_TOKEN", "test-token");
  Deno.env.delete("EVENTBRITE_ORGANIZATION_IDS");

  const response = await handler(new Request("http://localhost", {
    method: "POST",
    body: JSON.stringify({ dryRun: true }),
  }));
  const body = await response.json();

  assertEquals(response.status, 400);
  assertEquals(body.error, "At least one Eventbrite organization id is required");

  if (previousToken) {
    Deno.env.set("EVENTBRITE_OAUTH_TOKEN", previousToken);
  } else {
    Deno.env.delete("EVENTBRITE_OAUTH_TOKEN");
  }
  if (previousOrganizations) {
    Deno.env.set("EVENTBRITE_ORGANIZATION_IDS", previousOrganizations);
  }
});

Deno.test("classifies career events", () => {
  assertEquals(
    classifyEventSubcategory(event({ name: { text: "Startup networking workshop" } })),
    "career",
  );
});

Deno.test("classifies arts and culture events", () => {
  assertEquals(
    classifyEventSubcategory(event({ name: { text: "Korean music concert" } })),
    "arts_culture",
  );
});

Deno.test("normalizes Eventbrite event to pending content item", () => {
  const result = normalizeEventbriteEvent(event(), "org-1", baseRequest);
  assertEquals(result.skipped, false);
  if (result.skipped) throw new Error("Expected normalized event");

  assertEquals(result.event.row.source_type, "eventbrite");
  assertEquals(result.event.row.type, "event");
  assertEquals(result.event.row.category, "events");
  assertEquals(result.event.row.subcategories, ["social"]);
  assertEquals(result.event.row.is_active, false);
  assertEquals(result.event.row.is_approved, false);
  assertEquals(result.event.row.quality_score, 0);
  assertEquals(result.event.row.korean_community_fit, 0);
  assertEquals(result.event.row.vibe_tags, []);
  assertExists((result.event.row.source_refs as Record<string, unknown>).external_id);
});

Deno.test("events without start_at are skipped", () => {
  const result = normalizeEventbriteEvent(event({ start: {} }), "org-1", baseRequest);
  assertEquals(result.skipped, true);
  if (!result.skipped) throw new Error("Expected skipped event");
  assertEquals(result.reason, "outside_date_window_or_missing_start");
});

Deno.test("organizer filter skips non-matching organizers", () => {
  const request = parseImportRequest({
    dryRun: true,
    organizationIds: ["org-1"],
    organizerIds: ["wanted-organizer"],
  });
  const result = normalizeEventbriteEvent(event(), "org-1", request);
  assertEquals(result.skipped, true);
  if (!result.skipped) throw new Error("Expected skipped event");
  assertEquals(result.reason, "organizer_filtered");
});

Deno.test("update row preserves curator-owned fields", () => {
  const result = normalizeEventbriteEvent(event(), "org-1", baseRequest);
  if (result.skipped) throw new Error("Expected normalized event");
  const update = buildUpdateRow(result.event.row);

  assertEquals(update.title, "Korean Community Social");
  assertEquals(update.source_type, "eventbrite");
  assertEquals(update.is_active, undefined);
  assertEquals(update.is_approved, undefined);
  assertEquals(update.vibe_tags, undefined);
  assertEquals(update.activity_tags, undefined);
  assertEquals(update.quality_score, undefined);
  assertEquals(update.korean_community_fit, undefined);
  assertEquals(update.short_description, undefined);
  assertEquals(update.detail_description, undefined);
});

Deno.test("real import upsert updates existing Eventbrite rows instead of duplicating", async () => {
  const calls: unknown[] = [];
  const fakeSupabase = {
    from(table: string) {
      return {
        select() {
          return {
            eq() {
              return {
                filter() {
                  return {
                    limit() {
                      return Promise.resolve({ data: [{ id: "content-1" }], error: null });
                    },
                  };
                },
              };
            },
          };
        },
        update(row: Record<string, unknown>) {
          calls.push(["update", table, row]);
          return {
            eq() {
              return Promise.resolve({ error: null });
            },
          };
        },
        insert(row: Record<string, unknown>) {
          calls.push(["insert", table, row]);
          return Promise.resolve({ error: null });
        },
      };
    },
  };

  const result = normalizeEventbriteEvent(event(), "org-1", baseRequest);
  if (result.skipped) throw new Error("Expected normalized event");

  const counts = await upsertRows(fakeSupabase as never, [result.event]);

  assertEquals(counts, { inserted: 0, updated: 1 });
  assertEquals((calls[0] as unknown[])[0], "update");
});
