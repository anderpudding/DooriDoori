#!/usr/bin/env node
import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";

const repoRoot = process.cwd();
const sourceDir = path.join(repoRoot, "data/demo/source");
const appDataDir = path.join(
  repoRoot,
  "DooriDoori/DooriDoori/dooridoori_reviewed_mock_data",
);
const seedPath = path.join(repoRoot, "supabase/seed.sql");
const seedBatch = "dooridoori_demo_v2";
const uuidNamespace = "dooridoori-demo-content-v2";

const files = [
  ["events_demo.json", "reviewed_events_items.json"],
  ["food_demo.json", "reviewed_food_items.json"],
  ["lifestyle_demo.json", "reviewed_lifestyle_items.json"],
];

const allowed = {
  type: new Set(["place", "event", "lifestyle"]),
  category: new Set(["food", "events", "lifestyle"]),
  sourceType: new Set([
    "curated",
    "manual",
    "fsq",
    "fsq_os",
    "google_places",
    "meetup",
    "eventbrite",
    "city_open_data",
    "city_van",
    "luma",
  ]),
  scheduleType: new Set(["recurring", "one_time", "always_open"]),
};

function readJson(fileName) {
  return JSON.parse(fs.readFileSync(path.join(sourceDir, fileName), "utf8"));
}

function writeJson(fileName, value) {
  fs.writeFileSync(
    path.join(appDataDir, fileName),
    `${JSON.stringify(value, null, 2)}\n`,
  );
}

function normalizeText(value) {
  return String(value ?? "")
    .trim()
    .toLowerCase()
    .replaceAll("&", "and")
    .replace(/[^a-z0-9]+/g, "_")
    .replace(/^_+|_+$/g, "");
}

function stableUuid(input) {
  const hash = crypto
    .createHash("sha1")
    .update(`${uuidNamespace}:${input}`)
    .digest("hex");
  return [
    hash.slice(0, 8),
    hash.slice(8, 12),
    `5${hash.slice(13, 16)}`,
    ((parseInt(hash.slice(16, 18), 16) & 0x3f) | 0x80).toString(16) +
      hash.slice(18, 20),
    hash.slice(20, 32),
  ].join("-");
}

function budgetLevel(item) {
  const level = Number(item.priceLevel);
  if (level <= 1) return "low";
  if (level === 2) return "medium";
  if (level >= 3) return "high";
  return "any";
}

function sqlString(value) {
  if (value === null || value === undefined || value === "") return "null";
  return `'${String(value).replaceAll("'", "''")}'`;
}

function sqlArray(values) {
  const unique = [...new Set(values.filter(Boolean).map(String))];
  return `ARRAY[${unique.map(sqlString).join(", ")}]::text[]`;
}

function sqlJson(value) {
  return `$json$${JSON.stringify(value)}$json$::jsonb`;
}

function sqlNumber(value, fallback = 0) {
  const number = Number(value);
  return Number.isFinite(number) ? String(number) : String(fallback);
}

function toTimestamp(value) {
  if (!value) return null;
  const text = String(value);
  if (/[zZ]$|[+-]\d\d:\d\d$/.test(text)) return text;
  return `${text.length === 16 ? `${text}:00` : text}-07:00`;
}

function formatOpeningHours(openingHours) {
  if (!openingHours) return null;
  if (typeof openingHours === "string") return openingHours;
  if (typeof openingHours !== "object") return String(openingHours);

  const dayNames = [
    ["monday", "Mon"],
    ["tuesday", "Tue"],
    ["wednesday", "Wed"],
    ["thursday", "Thu"],
    ["friday", "Fri"],
    ["saturday", "Sat"],
    ["sunday", "Sun"],
  ];

  const parts = dayNames
    .map(([key, label]) => openingHours[key] ? `${label} ${openingHours[key]}` : null)
    .filter(Boolean);

  return parts.length ? parts.join("; ") : null;
}

function scheduleForApp(item) {
  const schedule = item.schedule ?? {};
  return {
    type: allowed.scheduleType.has(schedule.type) ? schedule.type : "recurring",
    openingHours: formatOpeningHours(schedule.openingHours),
    startDateTime: schedule.startDateTime ?? null,
    endDateTime: schedule.endDateTime ?? null,
  };
}

function derivedKoreanTags(item) {
  const haystack = [
    item.nameEn,
    item.nameKr,
    item.description,
    item.metadata?.cuisineType,
    item.metadata?.hostName,
  ].join(" ").toLowerCase();
  const tags = ["curated-for-vancouver-koreans"];

  if (
    haystack.includes("korean") ||
    haystack.includes("korea") ||
    haystack.includes("한인") ||
    haystack.includes("한국")
  ) {
    tags.push("korean-community", "korean-friendly");
  }
  if (haystack.includes("newcomer") || haystack.includes("이민자")) {
    tags.push("newcomer-friendly");
  }
  if (haystack.includes("family") || haystack.includes("가족")) {
    tags.push("family-friendly");
  }
  if (haystack.includes("student") || haystack.includes("유학생")) {
    tags.push("student-friendly");
  }
  if (item.category === "events" && item.subcategoryContent === "career") {
    tags.push("career-useful");
  }

  return [...new Set(tags)];
}

function activityTags(item, koreanTags) {
  return [...new Set([
    item.category,
    item.subcategoryContent,
    ...(Array.isArray(item.vibeTags) ? item.vibeTags : []),
    ...koreanTags,
  ].filter(Boolean))];
}

function qualityScore(item) {
  const popularity = Number(item.popularityScore ?? 0);
  const freshness = Number(item.freshnessScore ?? 0.5);
  return Math.max(0.45, Math.min(1, Number((popularity * 0.65 + freshness * 0.35).toFixed(3))));
}

function koreanCommunityFit(item, koreanTags) {
  if (koreanTags.includes("korean-community")) return 1;
  if (item.category === "food") return 0.6;
  if (item.category === "events") return 0.62;
  return 0.5;
}

function validateSourceItem(item, fileName) {
  const missing = [
    "id",
    "type",
    "category",
    "nameEn",
    "description",
    "district",
    "coordinates",
    "sourceType",
    "isActive",
  ].filter((key) => item[key] === undefined || item[key] === null);

  if (missing.length) {
    throw new Error(`${fileName}:${item.id ?? "unknown"} missing ${missing.join(", ")}`);
  }
  if (!allowed.type.has(item.type)) throw new Error(`${item.id} invalid type ${item.type}`);
  if (!allowed.category.has(item.category)) {
    throw new Error(`${item.id} invalid category ${item.category}`);
  }
  if (!allowed.sourceType.has(item.sourceType)) {
    throw new Error(`${item.id} invalid sourceType ${item.sourceType}`);
  }
  if (!Number.isFinite(Number(item.coordinates.lat)) || !Number.isFinite(Number(item.coordinates.lng))) {
    throw new Error(`${item.id} invalid coordinates`);
  }
}

function appItem(item) {
  const koreanTags = derivedKoreanTags(item);
  const schedule = scheduleForApp(item);
  return {
    ...item,
    subcategories: [item.subcategoryContent].filter(Boolean),
    image_url: item.imageURL ?? null,
    budget_level: budgetLevel(item),
    activity_tags: activityTags(item, koreanTags),
    korean_relevance_tags: koreanTags,
    schedule,
    quality_score: qualityScore(item),
    korean_community_fit: koreanCommunityFit(item, koreanTags),
    is_approved: true,
    view_count: Math.round(Number(item.popularityScore ?? 0) * 120),
    save_count: Math.round(Number(item.popularityScore ?? 0) * 24),
  };
}

function dbRow(item) {
  const normalized = appItem(item);
  const sourceRefs = {
    seed_batch: seedBatch,
    demo_id: item.id,
    name_en: item.nameEn,
    name_kr: item.nameKr ?? null,
    district: item.district,
    subcategory_display_kr: item.subcategoryDisplayKr ?? null,
    original_source_type: item.sourceType,
    data_quality: item.dataQuality ?? null,
    price_tier: item.priceTier ?? null,
    price_level: item.priceLevel ?? null,
    korean_relevance_tags: normalized.korean_relevance_tags,
    schedule: {
      ...(item.schedule ?? {}),
      openingHours: normalized.schedule.openingHours,
      originalOpeningHours: item.schedule?.openingHours ?? null,
    },
    dimension_scores: item.dimensionScores ?? {},
    metadata: item.metadata ?? {},
    popularity_score: item.popularityScore ?? null,
    freshness_score: item.freshnessScore ?? null,
    fsq_category_label: item._fsq_category_label ?? null,
  };

  return {
    id: stableUuid(item.id),
    title: item.nameKr ? `${item.nameKr} (${item.nameEn})` : item.nameEn,
    type: item.type,
    category: item.category,
    subcategories: normalized.subcategories,
    area: normalizeText(item.district),
    city: item.city ?? null,
    address: item.address ?? null,
    lat: Number(item.coordinates.lat),
    lng: Number(item.coordinates.lng),
    budget_level: normalized.budget_level,
    vibe_tags: Array.isArray(item.vibeTags) ? item.vibeTags : [],
    activity_tags: normalized.activity_tags,
    short_description: item.description,
    detail_description: item.description,
    image_url: item.imageURL ?? null,
    source_type: item.sourceType,
    source_refs: sourceRefs,
    quality_score: normalized.quality_score,
    korean_community_fit: normalized.korean_community_fit,
    is_active: Boolean(item.isActive),
    is_approved: true,
    view_count: normalized.view_count,
    save_count: normalized.save_count,
    review_count: Number(item.reviewCount ?? 0),
    average_rating: Number(item.rating ?? 0),
    start_at: item.type === "event" ? toTimestamp(item.schedule?.startDateTime) : null,
    end_at: item.type === "event" ? toTimestamp(item.schedule?.endDateTime) : null,
    created_at: item.createdAt ?? null,
    updated_at: item.updatedAt ?? null,
  };
}

function sqlRow(row) {
  return `(
  ${sqlString(row.id)},
  ${sqlString(row.title)},
  ${sqlString(row.type)},
  ${sqlString(row.category)},
  ${sqlArray(row.subcategories)},
  ${sqlString(row.area)},
  ${sqlString(row.city)},
  ${sqlString(row.address)},
  ${sqlNumber(row.lat)},
  ${sqlNumber(row.lng)},
  ${sqlString(row.budget_level)},
  ${sqlArray(row.vibe_tags)},
  ${sqlArray(row.activity_tags)},
  ${sqlString(row.short_description)},
  ${sqlString(row.detail_description)},
  ${sqlString(row.image_url)},
  ${sqlString(row.source_type)},
  ${sqlJson(row.source_refs)},
  ${sqlNumber(row.quality_score)},
  ${sqlNumber(row.korean_community_fit)},
  ${row.is_active ? "true" : "false"},
  ${row.is_approved ? "true" : "false"},
  ${sqlNumber(row.view_count)},
  ${sqlNumber(row.save_count)},
  ${sqlNumber(row.review_count)},
  ${sqlNumber(row.average_rating)},
  ${sqlString(row.start_at)},
  ${sqlString(row.end_at)},
  ${sqlString(row.created_at)},
  ${sqlString(row.updated_at)}
)`;
}

const sourceGroups = files.map(([sourceName, appName]) => {
  const items = readJson(sourceName);
  items.forEach((item) => validateSourceItem(item, sourceName));
  const normalized = items.map(appItem);
  writeJson(appName, normalized.filter((item) => item.isActive));
  return { sourceName, appName, items, normalized };
});

const allSourceItems = sourceGroups.flatMap((group) => group.items);
const appItems = sourceGroups.flatMap((group) => group.normalized).filter((item) => item.isActive);
const rows = allSourceItems.map(dbRow);
writeJson("dooridoori_mvp_content_items.json", appItems);

const columns = [
  "id",
  "title",
  "type",
  "category",
  "subcategories",
  "area",
  "city",
  "address",
  "lat",
  "lng",
  "budget_level",
  "vibe_tags",
  "activity_tags",
  "short_description",
  "detail_description",
  "image_url",
  "source_type",
  "source_refs",
  "quality_score",
  "korean_community_fit",
  "is_active",
  "is_approved",
  "view_count",
  "save_count",
  "review_count",
  "average_rating",
  "start_at",
  "end_at",
  "created_at",
  "updated_at",
];

const seedSql = `-- DooriDoori MVP demo content seed data
-- Generated by scripts/generate-demo-content.mjs from data/demo/source/*.json
-- Safe for local/dev seeding. It deletes and reinserts only rows tagged with source_refs.seed_batch = ${seedBatch}.

begin;

delete from public.content_items
where source_refs->>'seed_batch' = '${seedBatch}';

insert into public.content_items (
  ${columns.join(",\n  ")}
) values
${rows.map(sqlRow).join(",\n")};

commit;

-- Verification helpers:
-- select category, count(*) from public.content_items where source_refs->>'seed_batch' = '${seedBatch}' group by category order by category;
-- select category, count(*) filter (where not is_active) as inactive_count from public.content_items where source_refs->>'seed_batch' = '${seedBatch}' group by category order by category;
`;

fs.writeFileSync(seedPath, seedSql);

const summary = {
  sourceCounts: Object.fromEntries(sourceGroups.map((group) => [group.sourceName, group.items.length])),
  appActiveCount: appItems.length,
  dbSeedCount: rows.length,
  inactiveSeededCount: rows.filter((row) => !row.is_active).length,
  seedBatch,
};

console.log(JSON.stringify(summary, null, 2));
