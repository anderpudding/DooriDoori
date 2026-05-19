import assert from "node:assert/strict";
import test from "node:test";
import {
  buildUpdateRow,
  deriveDooriCategory,
  importRows,
  normalizeFsqRecord,
  normalizeRecords,
  SOURCE_TYPE,
} from "../fsq-os-places.mjs";

test("category mapping supports food subcategories", () => {
  assert.deepEqual(
    deriveDooriCategory(["Dining and Drinking > Restaurant > Korean Restaurant"]),
    { category: "food", subcategory: "food.restaurant" },
  );
  assert.deepEqual(
    deriveDooriCategory(["Dining and Drinking > Cafe"]),
    { category: "food", subcategory: "food.cafe" },
  );
  assert.deepEqual(
    deriveDooriCategory(["Nightlife > Bar"]),
    { category: "food", subcategory: "food.bar" },
  );
});

test("category mapping supports lifestyle subcategories", () => {
  assert.deepEqual(
    deriveDooriCategory(["Arts and Entertainment > Museum"]),
    { category: "lifestyle", subcategory: "lifestyle.culture" },
  );
  assert.deepEqual(
    deriveDooriCategory(["Landmarks and Outdoors > Park"]),
    { category: "lifestyle", subcategory: "lifestyle.nature" },
  );
  assert.deepEqual(
    deriveDooriCategory(["Sports and Recreation > Gym and Fitness Center"]),
    { category: "lifestyle", subcategory: "lifestyle.sport_venue" },
  );
});

test("irrelevant categories are skipped", () => {
  const result = normalizeFsqRecord({
    fsq_place_id: "office-1",
    name: "Office",
    fsq_category_labels: ["Business and Professional Services > Office"],
    locality: "Vancouver",
    latitude: 49.28,
    longitude: -123.12,
  });

  assert.equal(result.skipped, true);
  assert.equal(result.reason, "skipped_unmapped_category");
});

test("missing lat/lng is skipped", () => {
  const result = normalizeFsqRecord({
    fsq_place_id: "cafe-1",
    name: "Cafe",
    fsq_category_labels: ["Cafe"],
    locality: "Vancouver",
  });

  assert.equal(result.skipped, true);
  assert.equal(result.reason, "missing_lat_lng");
});

test("serious unresolved flags are skipped", () => {
  const result = normalizeFsqRecord({
    fsq_place_id: "deleted-1",
    name: "Deleted",
    fsq_category_labels: ["Restaurant"],
    locality: "Vancouver",
    latitude: 49.28,
    longitude: -123.12,
    unresolved_flags: ["delete"],
  });

  assert.equal(result.skipped, true);
  assert.equal(result.reason, "serious_unresolved_flags");
});

test("valid record normalizes to unapproved fsq_os content item", () => {
  const result = normalizeFsqRecord({
    fsq_place_id: "restaurant-1",
    name: "Restaurant",
    fsq_category_labels: ["Restaurant"],
    fsq_category_ids: ["13000"],
    locality: "Burnaby",
    region: "BC",
    country: "CA",
    latitude: 49.24,
    longitude: -122.98,
  });

  assert.equal(result.skipped, false);
  assert.equal(result.row.source_type, SOURCE_TYPE);
  assert.equal(result.row.type, "place");
  assert.equal(result.row.category, "food");
  assert.deepEqual(result.row.subcategories, ["food.restaurant"]);
  assert.equal(result.row.is_approved, false);
  assert.equal(result.row.is_active, true);
  assert.equal(result.row.korean_community_fit, 0);
  assert.deepEqual(result.row.vibe_tags, []);
});

test("duplicate FSQ ids in one export do not create duplicate import rows", () => {
  const records = [
    {
      fsq_place_id: "dupe-1",
      name: "Cafe A",
      fsq_category_labels: ["Cafe"],
      locality: "Vancouver",
      latitude: 49.28,
      longitude: -123.12,
    },
    {
      fsq_place_id: "dupe-1",
      name: "Cafe B",
      fsq_category_labels: ["Cafe"],
      locality: "Vancouver",
      latitude: 49.29,
      longitude: -123.13,
    },
  ];

  const result = normalizeRecords(records);
  assert.equal(result.rows.length, 1);
  assert.equal(result.skippedReasons.duplicate_fsq_place_id, 1);
});

test("importRows updates existing FSQ rows instead of inserting duplicates", async () => {
  const calls = [];
  const existingIds = new Map([["existing-1", "content-row-1"]]);
  const client = {
    async findExisting(fsqPlaceId) {
      const id = existingIds.get(fsqPlaceId);
      return id ? { id } : null;
    },
    async insertContent(row) {
      calls.push(["insert", row.source_refs.fsq_place_id]);
      existingIds.set(row.source_refs.fsq_place_id, `created-${row.source_refs.fsq_place_id}`);
    },
    async updateContent(id, row) {
      calls.push(["update", id, row.source_refs.fsq_place_id]);
    },
  };

  const rows = [
    { source_refs: { fsq_place_id: "existing-1" } },
    { source_refs: { fsq_place_id: "new-1" } },
  ];
  const result = await importRows(rows, client);

  assert.deepEqual(result, { insertedCount: 1, updatedCount: 1 });
  assert.deepEqual(calls, [
    ["update", "content-row-1", "existing-1"],
    ["insert", "new-1"],
  ]);
});

test("updates preserve curator-owned and app-owned fields", () => {
  const updateRow = buildUpdateRow({
    title: "Updated Cafe",
    source_type: SOURCE_TYPE,
    source_refs: { fsq_place_id: "existing-1" },
    is_approved: false,
    view_count: 0,
    save_count: 0,
    review_count: 0,
    average_rating: 0,
    quality_score: 0.5,
    korean_community_fit: 0,
    vibe_tags: [],
    activity_tags: [],
  });

  assert.equal(updateRow.title, "Updated Cafe");
  assert.equal(updateRow.source_type, SOURCE_TYPE);
  assert.equal(updateRow.is_approved, undefined);
  assert.equal(updateRow.view_count, undefined);
  assert.equal(updateRow.save_count, undefined);
  assert.equal(updateRow.review_count, undefined);
  assert.equal(updateRow.average_rating, undefined);
  assert.equal(updateRow.quality_score, undefined);
  assert.equal(updateRow.korean_community_fit, undefined);
  assert.equal(updateRow.vibe_tags, undefined);
  assert.equal(updateRow.activity_tags, undefined);
});

test("recommendation safety uses unapproved FSQ import default", () => {
  const result = normalizeFsqRecord({
    fsq_place_id: "park-1",
    name: "Park",
    fsq_category_labels: ["Park"],
    locality: "Vancouver",
    latitude: 49.28,
    longitude: -123.12,
  });

  assert.equal(result.row.is_active, true);
  assert.equal(result.row.is_approved, false);
});
