import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

export const DEFAULT_GEMINI_MODEL = "gemini-2.5-flash-lite";
const GEMINI_API_BASE = "https://generativelanguage.googleapis.com/v1beta";
const GEMINI_TIMEOUT_MS = 10_000;

type ContentItem = {
  id: string;
  title: string;
  type: "place" | "event" | "lifestyle";
  category: "food" | "events" | "lifestyle";
  subcategories: string[];
  area: string;
  city: string | null;
  budget_level: "low" | "medium" | "high" | "any";
  vibe_tags: string[];
  activity_tags: string[];
  short_description: string | null;
  image_url: string | null;
  quality_score: number;
  korean_community_fit: number;
  view_count: number;
  save_count: number;
  review_count: number;
  average_rating: number;
  created_at: string;
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
  activityMatch: number;
  locationMatch: number;
  budgetMatch: number;
  contentQuality: number;
  engagementScore: number;
  koreanCommunityFit: number;
  freshnessOrDiversity: number;
};

type StoredScoreBreakdown = ScoreBreakdown & {
  deterministicScore: number;
  geminiRank?: number;
  geminiConfidence?: number;
};

type RecommendedCandidate = ContentItem & {
  deterministic_score: number;
  score_breakdown: ScoreBreakdown;
};

type FinalRecommendation = RecommendedCandidate & {
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

type GeminiRerankerParams = {
  apiKey: string;
  modelName: string;
  userProfile: Record<string, unknown>;
  candidates: Record<string, unknown>[];
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

function safeArray(value: unknown): string[] {
  return Array.isArray(value)
    ? value.filter((item): item is string => typeof item === "string")
    : [];
}

function overlapRatio(userTags: string[], itemTags: string[]): number {
  if (!userTags.length) return 0.5;
  const itemSet = new Set(itemTags);
  const matches = userTags.filter((tag) => itemSet.has(tag)).length;
  return matches / userTags.length;
}

function categoryMatch(prefs: UserPreferences, item: ContentItem): number {
  if (!prefs.preferred_categories.length) return 0.5;
  return prefs.preferred_categories.includes(item.category) ? 1 : 0;
}

function locationMatch(prefs: UserPreferences, item: ContentItem): number {
  if (!prefs.preferred_areas.length) return 0.5;
  return prefs.preferred_areas.includes(item.area) ? 1 : 0.2;
}

function budgetMatch(prefs: UserPreferences, item: ContentItem): number {
  if (prefs.budget_level === "any" || item.budget_level === "any") return 1;
  if (prefs.budget_level === item.budget_level) return 1;

  const order = ["low", "medium", "high"];
  const userIndex = order.indexOf(prefs.budget_level);
  const itemIndex = order.indexOf(item.budget_level);

  if (userIndex === -1 || itemIndex === -1) return 0.5;
  return Math.abs(userIndex - itemIndex) === 1 ? 0.6 : 0.2;
}

function engagementScore(item: ContentItem): number {
  const raw = Math.log1p(item.save_count) * 0.6 +
    Math.log1p(item.review_count) * 0.25 +
    Math.log1p(item.view_count) * 0.15;

  return Math.min(raw / 5, 1);
}

function freshnessDiversityScore(item: ContentItem): number {
  const created = new Date(item.created_at).getTime();
  const now = Date.now();
  const ageDays = (now - created) / (1000 * 60 * 60 * 24);

  if (Number.isNaN(ageDays)) return 0.3;
  if (ageDays <= 7) return 1;
  if (ageDays <= 30) return 0.7;
  if (ageDays <= 90) return 0.4;
  return 0.2;
}

function calculateScore(prefs: UserPreferences, item: ContentItem) {
  const scores = {
    categoryMatch: categoryMatch(prefs, item),
    vibeMatch: overlapRatio(prefs.vibe_tags, item.vibe_tags),
    activityMatch: overlapRatio(prefs.activity_tags, item.activity_tags),
    locationMatch: locationMatch(prefs, item),
    budgetMatch: budgetMatch(prefs, item),
    contentQuality: Number(item.quality_score ?? 0),
    engagementScore: engagementScore(item),
    koreanCommunityFit: Number(item.korean_community_fit ?? 0),
    freshnessOrDiversity: freshnessDiversityScore(item),
  };

  const finalScore = 0.20 * scores.categoryMatch +
    0.18 * scores.vibeMatch +
    0.10 * scores.activityMatch +
    0.14 * scores.locationMatch +
    0.10 * scores.budgetMatch +
    0.12 * scores.contentQuality +
    0.07 * scores.engagementScore +
    0.06 * scores.koreanCommunityFit +
    0.03 * scores.freshnessOrDiversity;

  return {
    finalScore,
    scoreBreakdown: scores,
  };
}

function buildFallbackReason(_item: RecommendedCandidate): string {
  return "Matches your selected category, preferred area, and vibe preferences.";
}

function buildStoredScoreBreakdown(
  item: RecommendedCandidate,
  gemini?: { rank: number; confidence: number },
): StoredScoreBreakdown {
  return {
    deterministicScore: item.deterministic_score,
    ...item.score_breakdown,
    ...(gemini
      ? { geminiRank: gemini.rank, geminiConfidence: gemini.confidence }
      : {}),
  };
}

function geminiFinalScore(
  item: RecommendedCandidate,
  rank: number,
  confidence: number,
): number {
  const rankScore = (6 - rank) / 5;
  return Number(
    (item.deterministic_score * 0.7 + rankScore * confidence * 0.3).toFixed(6),
  );
}

export function buildDeterministicFallbackRecommendations(
  top20Candidates: RecommendedCandidate[],
  modelName = "deterministic_fallback",
): FinalRecommendation[] {
  return top20Candidates.slice(0, 5).map((item, index) => ({
    ...item,
    rank: index + 1,
    reason: buildFallbackReason(item),
    confidence: null,
    final_score: item.deterministic_score,
    model_name: modelName,
    stored_score_breakdown: buildStoredScoreBreakdown(item),
  }));
}

function serializeRecommendation(item: FinalRecommendation) {
  return {
    content: {
      id: item.id,
      title: item.title,
      type: item.type,
      category: item.category,
      area: item.area,
      budgetLevel: item.budget_level,
      vibeTags: item.vibe_tags,
      activityTags: item.activity_tags,
      shortDescription: item.short_description,
      imageUrl: item.image_url,
    },
    finalScore: item.final_score,
    deterministicScore: item.deterministic_score,
    rank: item.rank,
    reason: item.reason,
    confidence: item.confidence,
    modelName: item.model_name,
    scoreBreakdown: item.stored_score_breakdown,
  };
}

function compactUserProfile(prefs: UserPreferences): Record<string, unknown> {
  return {
    preferredCategories: prefs.preferred_categories,
    preferredAreas: prefs.preferred_areas,
    budgetLevel: prefs.budget_level,
    vibeTags: prefs.vibe_tags,
    activityTags: prefs.activity_tags,
    languagePreference: prefs.language_preference,
    negativeTags: prefs.negative_tags,
  };
}

function compactCandidate(item: RecommendedCandidate): Record<string, unknown> {
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
    deterministicScore: item.deterministic_score,
    scoreBreakdown: item.score_breakdown,
  };
}

function geminiInstruction(): string {
  return `You are the reranking engine for DooriDoori, a local discovery app for Vancouver Korean residents.

You will receive one user profile and exactly up to 20 candidate content items.
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
- Do not mention internal scoring details or model reasoning.
- Do not mention unavailable information.
- Output must follow the provided JSON schema.`;
}

async function callGeminiReranker(
  params: GeminiRerankerParams,
): Promise<GeminiRerankResult> {
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
                userProfile: params.userProfile,
                candidates: params.candidates,
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
      const errorText = await response.text();
      throw new Error(`Gemini API error: ${response.status} ${errorText}`);
    }

    const data = await response.json();
    const text = data?.candidates?.[0]?.content?.parts?.[0]?.text;

    if (typeof text !== "string" || !text.trim()) {
      throw new Error("Gemini returned empty response text.");
    }

    try {
      return JSON.parse(text) as GeminiRerankResult;
    } catch (error) {
      throw new Error(`Failed to parse Gemini JSON response: ${String(error)}`);
    }
  } finally {
    clearTimeout(timeoutId);
  }
}

export function parseGeminiRerankJson(text: string): GeminiRerankResult {
  try {
    return JSON.parse(text) as GeminiRerankResult;
  } catch (error) {
    throw new Error(`Failed to parse Gemini JSON response: ${String(error)}`);
  }
}

export function validateAndMergeGeminiResults(params: {
  geminiResult: GeminiRerankResult;
  top20Candidates: RecommendedCandidate[];
  modelName: string;
}): FinalRecommendation[] {
  const expectedCount = Math.min(5, params.top20Candidates.length);

  if (!Array.isArray(params.geminiResult.rankedItems)) {
    throw new Error("Gemini rankedItems was not an array");
  }

  if (params.geminiResult.rankedItems.length !== expectedCount) {
    throw new Error(
      `Gemini returned ${params.geminiResult.rankedItems.length} items; expected ${expectedCount}`,
    );
  }

  const byId = new Map(params.top20Candidates.map((item) => [item.id, item]));
  const usedIds = new Set<string>();
  const usedRanks = new Set<number>();

  const finalItems = params.geminiResult.rankedItems.map((rankedItem) => {
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
      stored_score_breakdown: buildStoredScoreBreakdown(candidate, {
        rank: rankedItem.rank,
        confidence: rankedItem.confidence,
      }),
    };
  });

  return finalItems.sort((a, b) => a.rank - b.rank);
}

export async function buildRerankedRecommendations(params: {
  geminiApiKey?: string;
  geminiModel: string;
  prefs: UserPreferences;
  top20Candidates: RecommendedCandidate[];
}): Promise<RerankOutcome> {
  if (!params.geminiApiKey) {
    return {
      recommendations: buildDeterministicFallbackRecommendations(
        params.top20Candidates,
      ),
      usedGemini: false,
      modelName: "deterministic_fallback",
      fallbackReason: "missing_gemini_api_key",
    };
  }

  try {
    const geminiResult = await callGeminiReranker({
      apiKey: params.geminiApiKey,
      modelName: params.geminiModel,
      userProfile: compactUserProfile(params.prefs),
      candidates: params.top20Candidates.map(compactCandidate),
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
      modelName: "deterministic_fallback",
      fallbackReason: error instanceof Error ? error.message : String(error),
    };
  }
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
    deterministic_score: item.deterministic_score,
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
  // current behavior for iOS Home For You because the app never has to
  // disambiguate historical batches while the schema is still evolving.
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

  const generatedAt = new Date().toISOString();
  const rows = buildRecommendationResultRows({
    userId: params.userId,
    recommendations: params.recommendations,
    generatedAt,
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
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
    const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")
      ?.trim();
    const geminiApiKey = Deno.env.get("GEMINI_API_KEY")?.trim();
    const geminiModel = Deno.env.get("GEMINI_MODEL")?.trim() ||
      DEFAULT_GEMINI_MODEL;

    const authHeader = req.headers.get("Authorization");

    if (!authHeader) {
      return jsonResponse({ error: "Missing Authorization header" }, 401);
    }

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
      .single();

    if (prefsError || !prefs) {
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

    const normalizedPrefs = {
      ...(prefs as UserPreferences),
      preferred_categories: safeArray((prefs as any).preferred_categories),
      preferred_areas: safeArray((prefs as any).preferred_areas),
      vibe_tags: safeArray((prefs as any).vibe_tags),
      activity_tags: safeArray((prefs as any).activity_tags),
      negative_tags: safeArray((prefs as any).negative_tags),
    } as UserPreferences;

    const top20Candidates = (items as ContentItem[])
      .filter((item) => item.quality_score >= 0.5)
      .filter((item) =>
        item.short_description && item.short_description.length > 0
      )
      .map((item) => {
        const result = calculateScore(normalizedPrefs, item);
        return {
          ...item,
          subcategories: safeArray(item.subcategories),
          vibe_tags: safeArray(item.vibe_tags),
          activity_tags: safeArray(item.activity_tags),
          quality_score: Number(item.quality_score ?? 0),
          korean_community_fit: Number(item.korean_community_fit ?? 0),
          average_rating: Number(item.average_rating ?? 0),
          view_count: Number(item.view_count ?? 0),
          save_count: Number(item.save_count ?? 0),
          review_count: Number(item.review_count ?? 0),
          deterministic_score: result.finalScore,
          score_breakdown: result.scoreBreakdown,
        };
      })
      .sort((a, b) => b.deterministic_score - a.deterministic_score)
      .slice(0, 20);

    console.info(`recommend-for-user candidate count: ${top20Candidates.length}`);

    if (!top20Candidates.length) {
      return jsonResponse({
        recommendations: [],
        metadata: {
          candidateCount: 0,
          returnedCount: 0,
          usedGemini: false,
          modelName: "none",
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
      },
    });
  } catch (error) {
    return jsonResponse({ error: String(error) }, 500);
  }
}

if (import.meta.main) {
  serve(handler);
}
