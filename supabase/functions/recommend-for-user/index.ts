import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const DETERMINISTIC_MODEL_NAME = "deterministic_v1";
const MIN_QUALITY_SCORE = 0.45;

type ContentItem = {
  id: string;
  title: string | null;
  type: "place" | "event" | "lifestyle";
  category: "food" | "events" | "lifestyle";
  subcategories: string[] | null;
  area: string | null;
  city: string | null;
  budget_level: "low" | "medium" | "high" | "any";
  vibe_tags: string[] | null;
  activity_tags: string[] | null;
  short_description: string | null;
  image_url: string | null;
  quality_score: number | null;
  korean_community_fit: number | null;
  view_count: number | null;
  save_count: number | null;
  review_count: number | null;
  average_rating: number | null;
  is_active: boolean;
  is_approved: boolean;
  created_at: string | null;
};

type UserPreferences = {
  preferred_categories: string[];
  preferred_areas: string[];
  budget_level: "low" | "medium" | "high" | "any";
  vibe_tags: string[];
  activity_tags: string[];
  language_preference: "korean_friendly" | "english_okay" | "any";
  travel_preference:
    | "walking_friendly"
    | "transit_friendly"
    | "driving_friendly"
    | "any";
  negative_tags: string[];
};

type ScoreBreakdown = {
  categoryMatch: number;
  vibeMatch: number;
  locationMatch: number;
  budgetMatch: number;
  contentQuality: number;
  engagementScore: number;
  freshnessOrDiversity: number;
};

type Candidate = ContentItem & {
  title: string;
  subcategories: string[];
  area: string;
  vibe_tags: string[];
  activity_tags: string[];
  short_description: string;
  quality_score: number;
  korean_community_fit: number;
  view_count: number;
  save_count: number;
  review_count: number;
  average_rating: number;
  recommendation_score: number;
  score_breakdown: ScoreBreakdown;
};

function jsonResponse(body: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

function clamp01(value: number): number {
  if (!Number.isFinite(value)) return 0;
  return Math.min(Math.max(value, 0), 1);
}

function normalizeText(value: string): string {
  return value.trim().toLowerCase().replaceAll("-", "_").replaceAll(" ", "_");
}

function safeArray(value: unknown): string[] {
  return Array.isArray(value)
    ? value.filter((item): item is string => typeof item === "string")
      .map(normalizeText)
      .filter(Boolean)
    : [];
}

function safeNumber(value: unknown, fallback = 0): number {
  const number = Number(value ?? fallback);
  return Number.isFinite(number) ? number : fallback;
}

function normalizePrefs(raw: Record<string, unknown>): UserPreferences {
  return {
    preferred_categories: safeArray(raw.preferred_categories),
    preferred_areas: safeArray(raw.preferred_areas),
    budget_level: typeof raw.budget_level === "string"
      ? raw.budget_level as UserPreferences["budget_level"]
      : "any",
    vibe_tags: safeArray(raw.vibe_tags),
    activity_tags: safeArray(raw.activity_tags),
    language_preference: typeof raw.language_preference === "string"
      ? raw.language_preference as UserPreferences["language_preference"]
      : "korean_friendly",
    travel_preference: typeof raw.travel_preference === "string"
      ? raw.travel_preference as UserPreferences["travel_preference"]
      : "any",
    negative_tags: safeArray(raw.negative_tags),
  };
}

function normalizeItem(item: ContentItem): Candidate | null {
  const title = item.title?.trim();
  const area = item.area?.trim();
  const shortDescription = item.short_description?.trim();

  if (!title || !item.category || !area || !shortDescription) return null;

  return {
    ...item,
    title,
    subcategories: safeArray(item.subcategories),
    area: normalizeText(area),
    vibe_tags: safeArray(item.vibe_tags),
    activity_tags: safeArray(item.activity_tags),
    short_description: shortDescription,
    image_url: item.image_url?.trim() || null,
    quality_score: clamp01(safeNumber(item.quality_score)),
    korean_community_fit: clamp01(safeNumber(item.korean_community_fit)),
    view_count: Math.max(0, safeNumber(item.view_count)),
    save_count: Math.max(0, safeNumber(item.save_count)),
    review_count: Math.max(0, safeNumber(item.review_count)),
    average_rating: Math.max(0, Math.min(safeNumber(item.average_rating), 5)),
    recommendation_score: 0,
    score_breakdown: {
      categoryMatch: 0,
      vibeMatch: 0,
      locationMatch: 0,
      budgetMatch: 0,
      contentQuality: 0,
      engagementScore: 0,
      freshnessOrDiversity: 0,
    },
  };
}

function overlapRatio(userTags: string[], itemTags: string[]): number {
  if (!userTags.length) return 0.5;
  if (!itemTags.length) return 0;

  const itemSet = new Set(itemTags);
  const matches = userTags.filter((tag) => itemSet.has(tag)).length;
  return clamp01(matches / userTags.length);
}

function categoryMatch(prefs: UserPreferences, item: Candidate): number {
  if (!prefs.preferred_categories.length) return 0.5;
  if (prefs.preferred_categories.includes(normalizeText(item.category))) return 1;

  const relatedTags = new Set([...item.subcategories, ...item.activity_tags]);
  return prefs.preferred_categories.some((category) => relatedTags.has(category))
    ? 0.5
    : 0;
}

function locationMatch(prefs: UserPreferences, item: Candidate): number {
  if (!prefs.preferred_areas.length) return 0.5;
  if (prefs.preferred_areas.includes(item.area)) return 1;

  const city = item.city ? normalizeText(item.city) : "";
  if (city && prefs.preferred_areas.includes(city)) return 0.6;

  return 0.2;
}

function budgetMatch(prefs: UserPreferences, item: Candidate): number {
  if (prefs.budget_level === "any" || item.budget_level === "any") return 1;
  if (prefs.budget_level === item.budget_level) return 1;

  const order = ["low", "medium", "high"];
  const userIndex = order.indexOf(prefs.budget_level);
  const itemIndex = order.indexOf(item.budget_level);

  if (userIndex === -1 || itemIndex === -1) return 0.5;
  return Math.abs(userIndex - itemIndex) === 1 ? 0.6 : 0.2;
}

function contentQuality(item: Candidate): number {
  return clamp01(item.quality_score * 0.7 + item.korean_community_fit * 0.3);
}

function engagementScore(item: Candidate): number {
  const raw = Math.log1p(item.save_count) * 0.6 +
    Math.log1p(item.review_count) * 0.25 +
    Math.log1p(item.view_count) * 0.15;

  return clamp01(raw / 5);
}

function freshnessOrDiversityScore(item: Candidate): number {
  if (!item.created_at) return 0.5;

  const created = new Date(item.created_at).getTime();
  const ageDays = (Date.now() - created) / (1000 * 60 * 60 * 24);

  if (!Number.isFinite(ageDays)) return 0.5;
  if (ageDays <= 7) return 1;
  if (ageDays <= 30) return 0.75;
  if (ageDays <= 90) return 0.5;
  return 0.3;
}

export function calculateDeterministicScore(
  prefs: UserPreferences,
  item: Candidate,
) {
  const scoreBreakdown: ScoreBreakdown = {
    categoryMatch: categoryMatch(prefs, item),
    vibeMatch: overlapRatio(prefs.vibe_tags, item.vibe_tags),
    locationMatch: locationMatch(prefs, item),
    budgetMatch: budgetMatch(prefs, item),
    contentQuality: contentQuality(item),
    engagementScore: engagementScore(item),
    freshnessOrDiversity: freshnessOrDiversityScore(item),
  };

  const recommendationScore =
    0.25 * scoreBreakdown.categoryMatch +
    0.20 * scoreBreakdown.vibeMatch +
    0.15 * scoreBreakdown.locationMatch +
    0.10 * scoreBreakdown.budgetMatch +
    0.15 * scoreBreakdown.contentQuality +
    0.10 * scoreBreakdown.engagementScore +
    0.05 * scoreBreakdown.freshnessOrDiversity;

  return {
    recommendationScore: clamp01(recommendationScore),
    scoreBreakdown,
  };
}

function itemPassesPreferenceFilter(
  prefs: UserPreferences,
  item: Candidate,
): boolean {
  const matchesCategory = !prefs.preferred_categories.length ||
    categoryMatch(prefs, item) > 0;
  const acceptableArea = !prefs.preferred_areas.length ||
    locationMatch(prefs, item) >= 0.2;
  const acceptableBudget = budgetMatch(prefs, item) >= 0.2;

  return matchesCategory && acceptableArea && acceptableBudget;
}

export function selectTopCandidates(params: {
  prefs: UserPreferences;
  items: ContentItem[];
  limit?: number;
}): Candidate[] {
  const normalizedItems = params.items
    .filter((item) => item.is_active && item.is_approved)
    .map(normalizeItem)
    .filter((item): item is Candidate => item !== null)
    .filter((item) => item.quality_score >= MIN_QUALITY_SCORE);

  const prefiltered = normalizedItems.filter((item) =>
    itemPassesPreferenceFilter(params.prefs, item)
  );
  const candidatePool = prefiltered.length >= 5 ? prefiltered : normalizedItems;

  return candidatePool
    .map((item) => {
      const score = calculateDeterministicScore(params.prefs, item);
      return {
        ...item,
        recommendation_score: score.recommendationScore,
        score_breakdown: score.scoreBreakdown,
      };
    })
    .sort((a, b) => b.recommendation_score - a.recommendation_score)
    .slice(0, params.limit ?? 20);
}

function deterministicReason(item: Candidate): string {
  return `Recommended because it matches your ${item.category} preferences in ${item.area}.`;
}

function serializeCandidate(item: Candidate, rank: number) {
  return {
    content: {
      id: item.id,
      title: item.title,
      type: item.type,
      category: item.category,
      subcategories: item.subcategories,
      area: item.area,
      city: item.city,
      budgetLevel: item.budget_level,
      vibeTags: item.vibe_tags,
      activityTags: item.activity_tags,
      shortDescription: item.short_description,
      imageUrl: item.image_url,
    },
    deterministicScore: item.recommendation_score,
    rank,
    reason: deterministicReason(item),
    modelName: DETERMINISTIC_MODEL_NAME,
    scoreBreakdown: item.score_breakdown,
  };
}

export function buildRecommendationResultRows(params: {
  userId: string;
  candidates: Candidate[];
  generatedAt: string;
}) {
  return params.candidates.map((item, index) => ({
    user_id: params.userId,
    content_id: item.id,
    rank: index + 1,
    final_score: item.recommendation_score,
    deterministic_score: item.recommendation_score,
    gemini_confidence: null,
    score_breakdown: item.score_breakdown,
    reason: deterministicReason(item),
    model_name: DETERMINISTIC_MODEL_NAME,
    generated_at: params.generatedAt,
  }));
}

async function saveRecommendationResults(params: {
  supabase: any;
  userId: string;
  candidates: Candidate[];
}) {
  const { error: deleteError } = await params.supabase
    .from("recommendation_results")
    .delete()
    .eq("user_id", params.userId);

  if (deleteError) {
    console.warn(
      `recommendation_results delete failed: ${deleteError.message}`,
    );
    return;
  }

  const rows = buildRecommendationResultRows({
    userId: params.userId,
    candidates: params.candidates,
    generatedAt: new Date().toISOString(),
  });

  const { error: insertError } = await params.supabase
    .from("recommendation_results")
    .insert(rows);

  if (insertError) {
    console.warn(
      `recommendation_results insert failed: ${insertError.message}`,
    );
  }
}

async function handler(req: Request): Promise<Response> {
  try {
    const authHeader = req.headers.get("Authorization");

    if (!authHeader) {
      return jsonResponse({ error: "Missing Authorization header" }, 401);
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
    const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")
      ?.trim();

    const supabase = createClient(supabaseUrl, supabaseAnonKey, {
      global: {
        headers: {
          Authorization: authHeader,
        },
      },
    });
    const persistenceClient = supabaseServiceRoleKey
      ? createClient(supabaseUrl, supabaseServiceRoleKey)
      : supabase;

    const {
      data: { user },
      error: userError,
    } = await supabase.auth.getUser();

    if (userError || !user) {
      return jsonResponse({ error: "Unauthorized" }, 401);
    }

    const { data: prefs, error: prefsError } = await supabase
      .from("user_preferences")
      .select("*")
      .eq("user_id", user.id)
      .maybeSingle();

    if (prefsError) {
      return jsonResponse({ error: prefsError.message }, 500);
    }

    if (!prefs) {
      return jsonResponse({ error: "User preferences not found" }, 404);
    }

    const { data: items, error: itemsError } = await supabase
      .from("content_items")
      .select("*")
      .eq("is_active", true)
      .eq("is_approved", true);

    if (itemsError) {
      return jsonResponse({ error: itemsError.message }, 500);
    }

    const candidates = selectTopCandidates({
      prefs: normalizePrefs(prefs),
      items: (items ?? []) as ContentItem[],
      limit: 20,
    });

    console.info(
      `recommend-for-user deterministic candidate count: ${candidates.length}`,
    );

    await saveRecommendationResults({
      supabase: persistenceClient,
      userId: user.id,
      candidates,
    });

    const serialized = candidates.map((item, index) =>
      serializeCandidate(item, index + 1)
    );

    return jsonResponse({
      candidates: serialized,
      // Compatibility for existing iOS decoding while Phase 3 transitions to
      // the canonical candidates key.
      recommendations: serialized,
      metadata: {
        candidateCount: candidates.length,
        returnedCount: candidates.length,
        usedGemini: false,
        phase: "deterministic_scoring",
        modelName: DETERMINISTIC_MODEL_NAME,
      },
    });
  } catch (error) {
    return jsonResponse({ error: String(error) }, 500);
  }
}

if (import.meta.main) {
  serve(handler);
}
