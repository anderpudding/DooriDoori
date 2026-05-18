#!/usr/bin/env node

import fs from "node:fs/promises";
import path from "node:path";
import process from "node:process";
import { fileURLToPath } from "node:url";

export const SOURCE_TYPE = "fsq_os";

const SERIOUS_FLAGS = new Set([
  "privatevenue",
  "private_venue",
  "inappropriate",
  "doesnt_exist",
  "duplicate",
  "delete",
]);

const DEFAULT_SUPPORTED_CITIES = [
  "Vancouver",
  "Burnaby",
  "Richmond",
  "North Vancouver",
  "West Vancouver",
  "New Westminster",
  "Coquitlam",
  "Port Moody",
  "Surrey",
];

const FOOD_RULES = [
  ["korean restaurant", "food.restaurant"],
  ["japanese restaurant", "food.restaurant"],
  ["chinese restaurant", "food.restaurant"],
  ["restaurant", "food.restaurant"],
  ["bistro", "food.restaurant"],
  ["noodle", "food.restaurant"],
  ["cafe", "food.cafe"],
  ["coffee shop", "food.cafe"],
  ["bakery", "food.cafe"],
  ["dessert", "food.cafe"],
  ["bar", "food.bar"],
];

const LIFESTYLE_RULES = [
  ["gym", "lifestyle.sport_venue"],
  ["fitness", "lifestyle.sport_venue"],
  ["sports facility", "lifestyle.sport_venue"],
  ["recreation", "lifestyle.sport_venue"],
  ["park", "lifestyle.nature"],
  ["nature", "lifestyle.nature"],
  ["museum", "lifestyle.culture"],
  ["gallery", "lifestyle.culture"],
  ["library", "lifestyle.culture"],
  ["cultural center", "lifestyle.culture"],
  ["shopping", "lifestyle.culture"],
  ["beauty", "lifestyle.culture"],
  ["salon", "lifestyle.culture"],
  ["spa", "lifestyle.culture"],
];

export function parseList(value) {
  if (Array.isArray(value)) return value.map(String).map((item) => item.trim()).filter(Boolean);
  if (value === null || value === undefined) return [];
  const text = String(value).trim();
  if (!text) return [];
  if (text.startsWith("[") && text.endsWith("]")) {
    try {
      const parsed = JSON.parse(text);
      return Array.isArray(parsed) ? parsed.map(String).map((item) => item.trim()).filter(Boolean) : [];
    } catch {
      return [];
    }
  }
  return text.split(/[|;,]/).map((item) => item.trim()).filter(Boolean);
}

function field(record, names) {
  for (const name of names) {
    const value = name.includes(".")
      ? name.split(".").reduce((current, part) => current?.[part], record)
      : record[name];
    if (value !== undefined && value !== null && String(value).trim() !== "") {
      return value;
    }
  }
  return null;
}

function numberField(record, names) {
  const value = field(record, names);
  if (value === null) return null;
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : null;
}

function normalizeFlag(flag) {
  return String(flag).trim().toLowerCase().replaceAll(" ", "_");
}

export function deriveDooriCategory(categoryLabels) {
  const haystack = categoryLabels.map((label) => label.toLowerCase()).join(" | ");

  for (const [needle, subcategory] of FOOD_RULES) {
    if (haystack.includes(needle)) {
      return { category: "food", subcategory };
    }
  }

  for (const [needle, subcategory] of LIFESTYLE_RULES) {
    if (haystack.includes(needle)) {
      return { category: "lifestyle", subcategory };
    }
  }

  return null;
}

export function normalizeFsqRecord(record, options = {}) {
  const supportedCities = new Set((options.supportedCities ?? DEFAULT_SUPPORTED_CITIES).map((city) => city.toLowerCase()));
  const fsqPlaceId = field(record, ["fsq_place_id", "fsq_id", "id", "place_id"]);
  const name = field(record, ["name", "nameEn", "title"]);
  const city = field(record, ["locality", "city"]);
  const area = field(record, ["district", "neighborhood", "locality", "city"]);
  const lat = numberField(record, ["latitude", "lat", "coordinates.lat"]);
  const lng = numberField(record, ["longitude", "lng", "coordinates.lng"]);
  const categoryLabels = parseList(field(record, ["fsq_category_labels", "category_labels", "categories", "category"]));
  const categoryIds = parseList(field(record, ["fsq_category_ids", "category_ids"]));
  const unresolvedFlags = parseList(field(record, ["unresolved_flags", "unresolvedFlags"]))
    .map(normalizeFlag);
  const isClosed = ["true", "1", "closed", "permanently_closed"].includes(
    String(field(record, ["closed", "is_closed", "business_status", "status"]) ?? "").trim().toLowerCase(),
  );
  const seriousFlags = unresolvedFlags.filter((flag) => SERIOUS_FLAGS.has(flag));
  const categoryMapping = deriveDooriCategory(categoryLabels);

  if (!fsqPlaceId) return { skipped: true, reason: "missing_fsq_place_id" };
  if (!name) return { skipped: true, reason: "missing_name", fsqPlaceId };
  if (!city || !supportedCities.has(String(city).trim().toLowerCase())) {
    return { skipped: true, reason: "outside_supported_city", fsqPlaceId };
  }
  if (lat === null || lng === null) return { skipped: true, reason: "missing_lat_lng", fsqPlaceId };
  if (isClosed) return { skipped: true, reason: "closed", fsqPlaceId };
  if (seriousFlags.length > 0) return { skipped: true, reason: "serious_unresolved_flags", fsqPlaceId };
  if (!categoryMapping) return { skipped: true, reason: "skipped_unmapped_category", fsqPlaceId };

  const address = field(record, ["address", "formatted_address"]) ?? "";
  const region = field(record, ["region", "province", "state"]);
  const country = field(record, ["country"]);
  const socials = {
    instagram: field(record, ["instagram"]),
    twitter: field(record, ["twitter"]),
    facebook: field(record, ["facebook"]),
  };
  for (const key of Object.keys(socials)) {
    if (!socials[key]) delete socials[key];
  }

  return {
    skipped: false,
    fsqPlaceId: String(fsqPlaceId),
    row: {
      title: String(name).trim(),
      type: "place",
      category: categoryMapping.category,
      subcategories: [categoryMapping.subcategory],
      area: String(area).trim(),
      city: String(city).trim(),
      address: String(address).trim() || null,
      lat,
      lng,
      budget_level: "any",
      vibe_tags: [],
      activity_tags: [],
      short_description: null,
      detail_description: null,
      image_url: null,
      source_type: SOURCE_TYPE,
      source_refs: {
        fsq_place_id: String(fsqPlaceId),
        fsq_category_labels: categoryLabels,
        fsq_category_ids: categoryIds,
        region,
        country,
        tel: field(record, ["tel", "phone"]),
        website: field(record, ["website", "url"]),
        socials,
        placemaker_url: field(record, ["placemaker_url"]),
        date_refreshed: field(record, ["date_refreshed"]),
        unresolved_flags: unresolvedFlags,
      },
      quality_score: 0.5,
      korean_community_fit: 0,
      is_active: true,
      is_approved: false,
      view_count: 0,
      save_count: 0,
      review_count: 0,
      average_rating: 0,
      start_at: null,
      end_at: null,
    },
  };
}

export function parseCsv(text) {
  const rows = [];
  let row = [];
  let value = "";
  let inQuotes = false;

  for (let index = 0; index < text.length; index += 1) {
    const char = text[index];
    const next = text[index + 1];
    if (char === '"' && inQuotes && next === '"') {
      value += '"';
      index += 1;
    } else if (char === '"') {
      inQuotes = !inQuotes;
    } else if (char === "," && !inQuotes) {
      row.push(value);
      value = "";
    } else if ((char === "\n" || char === "\r") && !inQuotes) {
      if (char === "\r" && next === "\n") index += 1;
      row.push(value);
      if (row.some((cell) => cell.trim() !== "")) rows.push(row);
      row = [];
      value = "";
    } else {
      value += char;
    }
  }
  row.push(value);
  if (row.some((cell) => cell.trim() !== "")) rows.push(row);

  const [headers, ...records] = rows;
  if (!headers) return [];
  return records.map((cells) =>
    Object.fromEntries(headers.map((header, index) => [header.trim(), cells[index] ?? ""]))
  );
}

export async function loadRecords(filePath) {
  const text = await fs.readFile(filePath, "utf8");
  if (filePath.endsWith(".csv")) return parseCsv(text);
  const parsed = JSON.parse(text);
  if (Array.isArray(parsed)) return parsed;
  if (Array.isArray(parsed.records)) return parsed.records;
  if (Array.isArray(parsed.places)) return parsed.places;
  throw new Error("FSQ sample export must be a JSON array, { records: [] }, { places: [] }, or CSV");
}

function increment(object, key) {
  object[key] = (object[key] ?? 0) + 1;
}

export function normalizeRecords(records, options = {}) {
  const seen = new Set();
  const skippedReasons = {};
  const rows = [];
  let duplicateInFileCount = 0;

  for (const record of records) {
    const normalized = normalizeFsqRecord(record, options);
    if (normalized.skipped) {
      increment(skippedReasons, normalized.reason);
      continue;
    }
    if (seen.has(normalized.fsqPlaceId)) {
      duplicateInFileCount += 1;
      increment(skippedReasons, "duplicate_fsq_place_id");
      continue;
    }
    seen.add(normalized.fsqPlaceId);
    rows.push(normalized.row);
  }

  return {
    rows,
    skippedReasons,
    duplicateInFileCount,
    skippedCount: Object.values(skippedReasons).reduce((sum, count) => sum + count, 0),
  };
}

function parseArgs(argv) {
  const args = {
    file: "supabase/seed_data/fsq_places_sample.json",
    dryRun: false,
    limit: null,
  };
  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index];
    if (arg === "--file") args.file = argv[++index];
    else if (arg === "--dry-run") args.dryRun = true;
    else if (arg === "--limit") args.limit = Number(argv[++index]);
    else if (arg === "--help" || arg === "-h") args.help = true;
  }
  return args;
}

function usage() {
  return `Usage: node scripts/importers/fsq-os-places.mjs --file supabase/seed_data/fsq_places_sample.json [--dry-run] [--limit 25]`;
}

class SupabaseRestClient {
  constructor({ url, serviceRoleKey }) {
    this.url = url.replace(/\/$/, "");
    this.headers = {
      apikey: serviceRoleKey,
      Authorization: `Bearer ${serviceRoleKey}`,
      "Content-Type": "application/json",
      Prefer: "return=representation",
    };
  }

  endpoint(table, query = "") {
    return `${this.url}/rest/v1/${table}${query}`;
  }

  async request(table, { method = "GET", query = "", body } = {}) {
    const response = await fetch(this.endpoint(table, query), {
      method,
      headers: this.headers,
      body: body === undefined ? undefined : JSON.stringify(body),
    });
    const text = await response.text();
    const data = text ? JSON.parse(text) : null;
    if (!response.ok) {
      throw new Error(`${method} ${table} failed: ${response.status} ${text}`);
    }
    return data;
  }

  async insertLog(metadata) {
    const [row] = await this.request("api_import_logs", {
      method: "POST",
      body: {
        source_type: SOURCE_TYPE,
        status: "running",
        inserted_count: 0,
        updated_count: 0,
        failed_count: 0,
        metadata,
      },
    });
    return row;
  }

  async finishLog(id, patch) {
    if (!id) return;
    await this.request("api_import_logs", {
      method: "PATCH",
      query: `?id=eq.${encodeURIComponent(id)}`,
      body: {
        ...patch,
        finished_at: new Date().toISOString(),
      },
    });
  }

  async findExisting(fsqPlaceId) {
    const query = `?select=id&source_type=eq.${SOURCE_TYPE}&source_refs->>fsq_place_id=eq.${encodeURIComponent(fsqPlaceId)}&limit=1`;
    const rows = await this.request("content_items", { query });
    return rows[0] ?? null;
  }

  async insertContent(row) {
    await this.request("content_items", { method: "POST", body: row });
  }

  async updateContent(id, row) {
    await this.request("content_items", {
      method: "PATCH",
      query: `?id=eq.${encodeURIComponent(id)}`,
      body: row,
    });
  }
}

export async function importRows(rows, client) {
  let insertedCount = 0;
  let updatedCount = 0;

  for (const row of rows) {
    const existing = await client.findExisting(row.source_refs.fsq_place_id);
    if (existing) {
      await client.updateContent(existing.id, buildUpdateRow(row));
      updatedCount += 1;
    } else {
      await client.insertContent(row);
      insertedCount += 1;
    }
  }

  return { insertedCount, updatedCount };
}

export function buildUpdateRow(row) {
  const {
    is_approved,
    view_count,
    save_count,
    review_count,
    average_rating,
    quality_score,
    korean_community_fit,
    vibe_tags,
    activity_tags,
    ...basePoiFields
  } = row;
  return basePoiFields;
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  if (args.help) {
    console.log(usage());
    return;
  }

  const filePath = path.resolve(process.cwd(), args.file);
  const records = await loadRecords(filePath);
  const limitedRecords = Number.isFinite(args.limit) && args.limit > 0
    ? records.slice(0, args.limit)
    : records;
  const normalized = normalizeRecords(limitedRecords);
  const summary = {
    source: SOURCE_TYPE,
    file: args.file,
    dryRun: args.dryRun,
    totalRead: limitedRecords.length,
    readyToImport: normalized.rows.length,
    skippedCount: normalized.skippedCount,
    skippedReasons: normalized.skippedReasons,
  };

  if (args.dryRun) {
    console.log(JSON.stringify({ ...summary, insertedCount: 0, updatedCount: 0 }, null, 2));
    return;
  }

  const url = process.env.SUPABASE_URL;
  const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (!url || !serviceRoleKey) {
    throw new Error("SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are required for non-dry-run imports");
  }

  const client = new SupabaseRestClient({ url, serviceRoleKey });
  let logId = null;
  try {
    const log = await client.insertLog({
      total_read: summary.totalRead,
      skipped_count: summary.skippedCount,
      skipped_reasons: summary.skippedReasons,
      dry_run: false,
      file: args.file,
    });
    logId = log.id;
    const result = await importRows(normalized.rows, client);
    await client.finishLog(logId, {
      status: "succeeded",
      inserted_count: result.insertedCount,
      updated_count: result.updatedCount,
      failed_count: 0,
      metadata: {
        total_read: summary.totalRead,
        skipped_count: summary.skippedCount,
        skipped_reasons: summary.skippedReasons,
        dry_run: false,
        file: args.file,
      },
    });
    console.log(JSON.stringify({ ...summary, ...result }, null, 2));
  } catch (error) {
    if (logId) {
      await client.finishLog(logId, {
        status: "failed",
        error_message: error instanceof Error ? error.message : String(error),
        metadata: {
          total_read: summary.totalRead,
          skipped_count: summary.skippedCount,
          skipped_reasons: summary.skippedReasons,
          dry_run: false,
          file: args.file,
        },
      });
    }
    throw error;
  }
}

const currentFile = fileURLToPath(import.meta.url);
if (process.argv[1] && path.resolve(process.argv[1]) === currentFile) {
  main().catch((error) => {
    console.error(error instanceof Error ? error.message : String(error));
    process.exitCode = 1;
  });
}
