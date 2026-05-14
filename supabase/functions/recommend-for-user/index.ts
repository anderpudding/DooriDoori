import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const DETERMINISTIC_MODEL_NAME = "deterministic_v1";
const FALLBACK_MODEL_NAME = "deterministic_fallback";
export const DEFAULT_GEMINI_MODEL = "gemini-2.5-flash-lite";
const GEMINI_API_BASE = "https://generativelanguage.googleapis.com/v1beta";
const GEMINI_TIMEOUT_MS = 10_000;
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

type StoredScoreBreakdown = ScoreBreakdown & {
  deterministicScore: number;
  geminiRank?: number;
  geminiConfidence?: number;
  fallback?: boolean;
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

type FinalRecommendation = Candidate & {
  rank: number;
  reason: string;
  confidence: number | null;
  final_score: number;
  model_name: string;
  stored_score_breakdown: StoredScoreBreakdown;
};

type GeminiRerankItem = {
  id: string;
  rank: number;
  reason: string;
  confidence: number;
};

type GeminiRerankResult = {
  rankedItems: GeminiRerankItem[];
};

type RerankOutcome = {
  recommendations: FinalRecommendation[];
  usedGemini: boolean;
  modelName: string;
  fallbackReason?: string;
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

function deterministicReason(_item: Candidate): string {
  return "Matches your selected category, preferred area, and vibe preferences.";
}

function storedScoreBreakdown(
  item: Candidate,
  extra?: {
    geminiRank?: number;
    geminiConfidence?: number;
    fallback?: boolean;
  },
): StoredScoreBreakdown {
  return {
    ...item.score_breakdown,
    deterministicScore: item.recommendation_score,
    ...(extra?.geminiRank !== undefined ? { geminiRank: extra.geminiRank } : {}),
    ...(extra?.geminiConfidence !== undefined
      ? { geminiConfidence: extra.geminiConfidence }
      : {}),
    ...(extra?.fallback ? { fallback: true } : {}),
  };
}

function rankScore(rank: number): number {
  return (6 - rank) / 5;
}

function geminiFinalScore(
  item: Candidate,
  rank: number,
  confidence: number,
): number {
  return clamp01(
    item.recommendation_score * 0.70 +
      confidence * 0.20 +
      rankScore(rank) * 0.10,
  );
}

function compactUserProfile(prefs: UserPreferences): Record<string, unknown> {
  return {
    preferredCategories: prefs.preferred_categories,
    preferredAreas: prefs.preferred_areas,
    budgetLevel: prefs.budget_level,
    vibeTags: prefs.vibe_tags,
    activityTags: prefs.activity_tags,
    languagePreference: prefs.language_preference,
    travelPreference: prefs.travel_preference,
    negativeTags: prefs.negative_tags,
  };
}

function compactCandidate(item: Candidate): Record<string, unknown> {
  return {
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
    qualityScore: item.quality_score,
    koreanCommunityFit: item.korean_community_fit,
    viewCount: item.view_count,
    saveCount: item.save_count,
    reviewCount: item.review_count,
    averageRating: item.average_rating,
    deterministicScore: item.recommendation_score,
    scoreBreakdown: item.score_breakdown,
  };
}

function geminiInstruction(): string {
  return `You are the reranking engine for DooriDoori, a local discovery app for Vancouver Korean residents.

You will receive one user profile and up to 20 candidate content items.
Your task is to select the best 5 items for this user.

Rules:
- Only select ids from the provided candidates.
- Do not invent new ids, places, events, or facts.
- Use deterministicScore as an important signal, but improve the final ranking based on contextual fit.
- Prioritize user preference match, Korean-community relevance, area match, vibe/activity match, budget fit, quality, and engagement.
- Avoid recommending items that strongly match negativeTags.
- Return exactly 5 items if at least 5 candidates are provided.
- Return fewer only if fewer candidates are provided.
- Each reason must be short, user-facing, and based only on provided metadata.
- Do not mention internal scoring details.
- Do not mention model reasoning.
- Do not mention unavailable information.
- Output must be valid JSON matching the schema.`;
}

export function parseGeminiRerankJson(text: string): GeminiRerankResult {
  try {
    return JSON.parse(text) as GeminiRerankResult;
  } catch (error) {
    throw new Error(`Failed to parse Gemini JSON response: ${String(error)}`);
  }
}

async function callGeminiReranker(params: {
  apiKey: string;
  modelName: string;
  prefs: UserPreferences;
  candidates: Candidate[];
}): Promise<GeminiRerankResult> {
  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), GEMINI_TIMEOUT_MS);
  const endpoint =
    `${GEMINI_API_BASE}/models/${params.modelName}:generateContent?key=${params.apiKey}`;

  try {
    const response = await fetch(endpoint, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        systemInstruction: {
          parts: [{ text: geminiInstruction() }],
        },
        contents: [
          {
            role: "user",
            parts: [{
              text: JSON.stringify({
                userProfile: compactUserProfile(params.prefs),
                candidates: params.candidates.map(compactCandidate),
              }),
            }],
          },
        ],
        generationConfig: {
          temperature: 0.15,
          maxOutputTokens: 1000,
          responseMimeType: "application/json",
          responseSchema: {
            type: "OBJECT",
            properties: {
              rankedItems: {
                type: "ARRAY",
                items: {
                  type: "OBJECT",
                  properties: {
                    id: { type: "STRING" },
                    rank: { type: "INTEGER" },
                    reason: { type: "STRING" },
                    confidence: { type: "NUMBER" },
                  },
                  required: ["id", "rank", "reason", "confidence"],
                },
              },
            },
            required: ["rankedItems"],
          },
        },
      }),
      signal: controller.signal,
    });

    if (!response.ok) {
      throw new Error(`Gemini API error: ${response.status}`);
    }

    const data = await response.json();
    const text = data?.candidates?.[0]?.content?.parts?.[0]?.text;

    if (typeof text !== "string" || !text.trim()) {
      throw new Error("Gemini returned empty response text");
    }

    return parseGeminiRerankJson(text);
  } finally {
    clearTimeout(timeoutId);
  }
}

export function validateAndMergeGeminiResults(params: {
  geminiResult: GeminiRerankResult;
  top20Candidates: Candidate[];
  modelName: string;
}): FinalRecommendation[] {
  const expectedCount = Math.min(5, params.top20Candidates.length);

  if (!Array.isArray(params.geminiResult.rankedItems)) {
    throw new Error("Gemini rankedItems was not an array");
  }

  if (
    params.geminiResult.rankedItems.length > 5 ||
    params.geminiResult.rankedItems.length !== expectedCount
  ) {
    throw new Error(
      `Gemini returned ${params.geminiResult.rankedItems.length} rankedItems; expected ${expectedCount}`,
    );
  }

  const byId = new Map(params.top20Candidates.map((item) => [item.id, item]));
  const usedIds = new Set<string>();
  const usedRanks = new Set<number>();

  const recommendations = params.geminiResult.rankedItems.map((rankedItem) => {
    if (typeof rankedItem.id !== "string" || !byId.has(rankedItem.id)) {
      throw new Error(`Gemini returned unknown candidate id: ${rankedItem.id}`);
    }
    if (usedIds.has(rankedItem.id)) {
      throw new Error(`Gemini returned duplicate id: ${rankedItem.id}`);
    }
    if (
      !Number.isInteger(rankedItem.rank) ||
      rankedItem.rank < 1 ||
      rankedItem.rank > expectedCount
    ) {
      throw new Error(`Gemini returned invalid rank for id: ${rankedItem.id}`);
    }
    if (usedRanks.has(rankedItem.rank)) {
      throw new Error(`Gemini returned duplicate rank: ${rankedItem.rank}`);
    }
    if (
      typeof rankedItem.reason !== "string" ||
      rankedItem.reason.trim().length === 0
    ) {
      throw new Error(`Gemini returned empty reason for id: ${rankedItem.id}`);
    }
    if (
      typeof rankedItem.confidence !== "number" ||
      rankedItem.confidence < 0 ||
      rankedItem.confidence > 1
    ) {
      throw new Error(
        `Gemini returned invalid confidence for id: ${rankedItem.id}`,
      );
    }

    usedIds.add(rankedItem.id);
    usedRanks.add(rankedItem.rank);

    const candidate = byId.get(rankedItem.id)!;
    return {
      ...candidate,
      rank: rankedItem.rank,
      reason: rankedItem.reason.trim(),
      confidence: rankedItem.confidence,
      final_score: geminiFinalScore(
        candidate,
        rankedItem.rank,
        rankedItem.confidence,
      ),
      model_name: params.modelName,
      stored_score_breakdown: storedScoreBreakdown(candidate, {
        geminiRank: rankedItem.rank,
        geminiConfidence: rankedItem.confidence,
      }),
    };
  });

  return recommendations.sort((a, b) => a.rank - b.rank);
}

export function buildDeterministicFallbackRecommendations(
  candidates: Candidate[],
): FinalRecommendation[] {
  return candidates.slice(0, 5).map((item, index) => ({
    ...item,
    rank: index + 1,
    reason: deterministicReason(item),
    confidence: null,
    final_score: item.recommendation_score,
    model_name: FALLBACK_MODEL_NAME,
    stored_score_breakdown: storedScoreBreakdown(item, { fallback: true }),
  }));
}

export async function buildRerankedRecommendations(params: {
  geminiApiKey?: string;
  geminiModel: string;
  prefs: UserPreferences;
  top20Candidates: Candidate[];
  reranker?: () => Promise<GeminiRerankResult>;
}): Promise<RerankOutcome> {
  if (!params.geminiApiKey) {
    return {
      recommendations: buildDeterministicFallbackRecommendations(
        params.top20Candidates,
      ),
      usedGemini: false,
      modelName: FALLBACK_MODEL_NAME,
      fallbackReason: "missing_gemini_api_key",
    };
  }

  try {
    const geminiResult = params.reranker
      ? await params.reranker()
      : await callGeminiReranker({
        apiKey: params.geminiApiKey,
        modelName: params.geminiModel,
        prefs: params.prefs,
        candidates: params.top20Candidates,
      });

    return {
      recommendations: validateAndMergeGeminiResults({
        geminiResult,
        top20Candidates: params.top20Candidates,
        modelName: params.geminiModel,
      }),
      usedGemini: true,
      modelName: params.geminiModel,
    };
  } catch (error) {
    return {
      recommendations: buildDeterministicFallbackRecommendations(
        params.top20Candidates,
      ),
      usedGemini: false,
      modelName: FALLBACK_MODEL_NAME,
      fallbackReason: error instanceof Error ? error.message : String(error),
    };
  }
}

function serializeRecommendation(item: FinalRecommendation) {
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
    finalScore: item.final_score,
    deterministicScore: item.recommendation_score,
    rank: item.rank,
    reason: item.reason,
    confidence: item.confidence,
    modelName: item.model_name,
    scoreBreakdown: item.stored_score_breakdown,
  };
}

export function buildRecommendationResultRows(params: {
  userId: string;
  recommendations: FinalRecommendation[];
  generatedAt: string;
}) {
  return params.recommendations.map((item) => ({
    user_id: params.userId,
    content_id: item.id,
    rank: item.rank,
    final_score: item.final_score,
    deterministic_score: item.recommendation_score,
    gemini_confidence: item.confidence,
    score_breakdown: item.stored_score_breakdown,
    reason: item.reason,
    model_name: item.model_name,
    generated_at: params.generatedAt,
  }));
}

async function saveRecommendationResults(params: {
  supabase: any;
  userId: string;
  recommendations: FinalRecommendation[];
}) {
  // Keep only the latest recommendation batch per user. This is the simplest
  // safe approach for the current iOS Home For You flow because the client does
  // not need to choose between historical generated_at batches.
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
    recommendations: params.recommendations,
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
    const geminiApiKey = Deno.env.get("GEMINI_API_KEY")?.trim();
    const geminiModel = Deno.env.get("GEMINI_MODEL")?.trim() ||
      DEFAULT_GEMINI_MODEL;

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

    const normalizedPrefs = normalizePrefs(prefs);
    const top20Candidates = selectTopCandidates({
      prefs: normalizedPrefs,
      items: (items ?? []) as ContentItem[],
      limit: 20,
    });

    console.info(
      `recommend-for-user deterministic candidate count: ${top20Candidates.length}`,
    );

    if (!top20Candidates.length) {
      return jsonResponse({
        recommendations: [],
        metadata: {
          candidateCount: 0,
          returnedCount: 0,
          usedGemini: false,
          modelName: "none",
          phase: "gemini_reranking",
        },
      });
    }

    const rerankOutcome = await buildRerankedRecommendations({
      geminiApiKey,
      geminiModel,
      prefs: normalizedPrefs,
      top20Candidates,
    });

    await saveRecommendationResults({
      supabase: persistenceClient,
      userId: user.id,
      recommendations: rerankOutcome.recommendations,
    });

    console.info(
      `recommend-for-user usedGemini=${rerankOutcome.usedGemini} returned=${rerankOutcome.recommendations.length}`,
    );
    if (rerankOutcome.fallbackReason) {
      console.warn(
        `recommend-for-user fallback reason: ${rerankOutcome.fallbackReason}`,
      );
    }

    return jsonResponse({
      recommendations: rerankOutcome.recommendations.map(
        serializeRecommendation,
      ),
      metadata: {
        candidateCount: top20Candidates.length,
        returnedCount: rerankOutcome.recommendations.length,
        usedGemini: rerankOutcome.usedGemini,
        modelName: rerankOutcome.modelName,
        phase: "gemini_reranking",
      },
    });
  } catch (error) {
    return jsonResponse({ error: String(error) }, 500);
  }
}

if (import.meta.main) {
  serve(handler);
}
