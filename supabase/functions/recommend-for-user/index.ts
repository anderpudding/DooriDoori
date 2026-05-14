import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const GEMINI_MODEL = "gemini-2.5-flash-lite";
const GEMINI_ENDPOINT =
  `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent`;

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

type RecommendedCandidate = ContentItem & {
  deterministic_score: number;
  score_breakdown: ScoreBreakdown;
};

type FinalRecommendation = RecommendedCandidate & {
  rank: number;
  reason: string;
  gemini_confidence: number | null;
};

type RecommendationResponseItem = {
  id: string;
  title: string;
  type: ContentItem["type"];
  category: ContentItem["category"];
  subcategories: string[];
  area: string;
  city: string | null;
  budget_level: ContentItem["budget_level"];
  vibe_tags: string[];
  activity_tags: string[];
  short_description: string | null;
  image_url: string | null;
  rank: number;
  reason: string;
  gemini_confidence: number | null;
  deterministic_score: number;
  score_breakdown: ScoreBreakdown;
};

type GeminiRerankResult = {
  rankedItems: Array<{
    id?: unknown;
    rank?: unknown;
    reason?: unknown;
    confidence?: unknown;
  }>;
};

function jsonResponse(body: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
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

function buildFallbackReason(item: RecommendedCandidate): string {
  const parts = [item.category, item.area, item.vibe_tags?.[0]]
    .filter((value): value is string => Boolean(value));

  if (!parts.length) {
    return "Recommended because it matches your current preferences.";
  }

  return `Recommended because it matches your preferences for ${
    parts.join(", ")
  }.`;
}

function buildDeterministicFallbackRecommendations(
  top20Candidates: RecommendedCandidate[],
): FinalRecommendation[] {
  return top20Candidates.slice(0, 5).map((item, index) => ({
    ...item,
    rank: index + 1,
    reason: buildFallbackReason(item),
    gemini_confidence: null,
  }));
}

function serializeRecommendation(
  item: FinalRecommendation,
): RecommendationResponseItem {
  return {
    id: item.id,
    title: item.title,
    type: item.type,
    category: item.category,
    subcategories: item.subcategories,
    area: item.area,
    city: item.city,
    budget_level: item.budget_level,
    vibe_tags: item.vibe_tags,
    activity_tags: item.activity_tags,
    short_description: item.short_description,
    image_url: item.image_url,
    rank: item.rank,
    reason: item.reason,
    gemini_confidence: item.gemini_confidence,
    deterministic_score: item.deterministic_score,
    score_breakdown: item.score_breakdown,
  };
}

function serializeRecommendations(
  items: FinalRecommendation[],
): RecommendationResponseItem[] {
  return items.map(serializeRecommendation);
}

function buildDeterministicFallbackResponse(
  top20Candidates: RecommendedCandidate[],
) {
  console.warn("Using deterministic recommendation fallback");
  return {
    recommendations: serializeRecommendations(
      buildDeterministicFallbackRecommendations(top20Candidates),
    ),
    source: "deterministic_fallback",
  };
}

function compactUserProfile(prefs: UserPreferences): Record<string, unknown> {
  return {
    preferred_categories: prefs.preferred_categories,
    preferred_areas: prefs.preferred_areas,
    budget_level: prefs.budget_level,
    vibe_tags: prefs.vibe_tags,
    activity_tags: prefs.activity_tags,
    language_preference: prefs.language_preference,
    travel_preference: prefs.travel_preference,
    negative_tags: prefs.negative_tags,
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
    budget_level: item.budget_level,
    vibe_tags: item.vibe_tags,
    activity_tags: item.activity_tags,
    short_description: item.short_description,
    quality_score: item.quality_score,
    korean_community_fit: item.korean_community_fit,
    view_count: item.view_count,
    save_count: item.save_count,
    review_count: item.review_count,
    deterministic_score: item.deterministic_score,
    score_breakdown: item.score_breakdown,
  };
}

function buildGeminiPrompt(params: {
  userProfile: Record<string, unknown>;
  candidates: Record<string, unknown>[];
}): string {
  return JSON.stringify({
    instruction: [
      "You are the recommendation reranking engine for DooriDoori.",
      "Choose exactly Top 5 items from the provided candidates.",
      "Never invent new items.",
      "Never return an id outside the candidate list.",
      "Use only the provided structured metadata.",
      "Do not use external knowledge.",
      "Do not mention Google reviews or scraped reviews.",
      "Return valid JSON only.",
      "No markdown.",
      "No commentary outside JSON.",
    ],
    rankingCriteria: [
      "user preference fit",
      "category match",
      "area/location match",
      "budget match",
      "vibe match",
      "activity match",
      "content quality",
      "engagement signal",
      "Korean community fit",
    ],
    expectedOutput: {
      rankedItems: [
        {
          id: "candidate_id",
          rank: 1,
          reason: "Short personalized reason.",
          confidence: 0.87,
        },
      ],
    },
    userProfile: params.userProfile,
    candidates: params.candidates,
  });
}

async function callGeminiReranker(params: {
  apiKey: string;
  userProfile: Record<string, unknown>;
  candidates: Record<string, unknown>[];
}): Promise<GeminiRerankResult> {
  const response = await fetch(
    `${GEMINI_ENDPOINT}?key=${encodeURIComponent(params.apiKey)}`,
    {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        contents: [
          {
            role: "user",
            parts: [{ text: buildGeminiPrompt(params) }],
          },
        ],
        generationConfig: {
          temperature: 0.2,
          maxOutputTokens: 1200,
          responseMimeType: "application/json",
        },
      }),
    },
  );

  if (!response.ok) {
    throw new Error(`Gemini API request failed with status ${response.status}`);
  }

  const data = await response.json();
  const text = data?.candidates?.[0]?.content?.parts?.[0]?.text;

  if (typeof text !== "string" || !text.trim()) {
    throw new Error("Gemini response was empty");
  }

  try {
    return JSON.parse(text) as GeminiRerankResult;
  } catch (error) {
    console.warn("Invalid Gemini JSON received");
    throw new Error(`Gemini response was not valid JSON: ${String(error)}`);
  }
}

function validateAndMergeGeminiResults(params: {
  geminiResult: GeminiRerankResult;
  top20Candidates: RecommendedCandidate[];
}): FinalRecommendation[] {
  if (!Array.isArray(params.geminiResult.rankedItems)) {
    console.warn("Gemini rankedItems was not an array");
    throw new Error("Gemini rankedItems was not an array");
  }

  const byId = new Map(params.top20Candidates.map((item) => [item.id, item]));
  const usedIds = new Set<string>();
  const finalItems: FinalRecommendation[] = [];

  for (const rankedItem of params.geminiResult.rankedItems) {
    if (typeof rankedItem.id !== "string") continue;
    if (usedIds.has(rankedItem.id)) continue;

    const candidate = byId.get(rankedItem.id);
    if (!candidate) continue;

    const reason = typeof rankedItem.reason === "string" &&
        rankedItem.reason.trim().length > 0
      ? rankedItem.reason.trim()
      : buildFallbackReason(candidate);
    const confidence = typeof rankedItem.confidence === "number" &&
        rankedItem.confidence >= 0 &&
        rankedItem.confidence <= 1
      ? rankedItem.confidence
      : null;

    finalItems.push({
      ...candidate,
      rank: finalItems.length + 1,
      reason,
      gemini_confidence: confidence,
    });
    usedIds.add(rankedItem.id);

    if (finalItems.length === 5) break;
  }

  if (!finalItems.length) {
    throw new Error("Gemini returned no valid candidate ids");
  }

  if (finalItems.length < 5) {
    for (const candidate of params.top20Candidates) {
      if (usedIds.has(candidate.id)) continue;

      finalItems.push({
        ...candidate,
        rank: finalItems.length + 1,
        reason: buildFallbackReason(candidate),
        gemini_confidence: null,
      });
      usedIds.add(candidate.id);

      if (finalItems.length === 5) break;
    }
  }

  console.info(
    `Gemini validation produced ${finalItems.length} valid recommendations`,
  );
  return finalItems;
}

async function saveRecommendationResults(params: {
  supabase: any;
  userId: string;
  recommendations: FinalRecommendation[];
  modelName: string;
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

  const generatedAt = new Date().toISOString();
  const rows = params.recommendations.map((item) => ({
    user_id: params.userId,
    content_id: item.id,
    rank: item.rank,
    final_score: item.gemini_confidence ?? item.deterministic_score,
    deterministic_score: item.deterministic_score,
    gemini_confidence: item.gemini_confidence,
    score_breakdown: item.score_breakdown,
    reason: item.reason,
    model_name: params.modelName,
    generated_at: generatedAt,
  }));

  const { error: insertError } = await params.supabase
    .from("recommendation_results")
    .insert(rows);

  if (insertError) {
    console.warn(
      `recommendation_results insert failed: ${insertError.message}`,
    );
  }
}

serve(async (req) => {
  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
    const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")
      ?.trim();

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

    const top20Candidates = (items as ContentItem[])
      .filter((item) => item.quality_score >= 0.5)
      .filter((item) =>
        item.short_description && item.short_description.length > 0
      )
      .map((item) => {
        const result = calculateScore(prefs as UserPreferences, item);
        return {
          ...item,
          deterministic_score: result.finalScore,
          score_breakdown: result.scoreBreakdown,
        };
      })
      .sort((a, b) => b.deterministic_score - a.deterministic_score)
      .slice(0, 20);

    if (!top20Candidates.length) {
      return jsonResponse({ recommendations: [], source: "empty" });
    }

    const geminiApiKey = Deno.env.get("GEMINI_API_KEY")?.trim();

    if (!geminiApiKey) {
      console.warn(
        "GEMINI_API_KEY is missing; returning deterministic fallback",
      );
      const fallback = buildDeterministicFallbackResponse(top20Candidates);
      const fallbackRecommendations = buildDeterministicFallbackRecommendations(
        top20Candidates,
      );
      await saveRecommendationResults({
        supabase: persistenceClient,
        userId: user.id,
        recommendations: fallbackRecommendations,
        modelName: "deterministic_fallback",
      });
      return jsonResponse(fallback);
    }

    try {
      const geminiResult = await callGeminiReranker({
        apiKey: geminiApiKey,
        userProfile: compactUserProfile(prefs as UserPreferences),
        candidates: top20Candidates.map(compactCandidate),
      });
      const recommendations = validateAndMergeGeminiResults({
        geminiResult,
        top20Candidates,
      });

      await saveRecommendationResults({
        supabase: persistenceClient,
        userId: user.id,
        recommendations,
        modelName: GEMINI_MODEL,
      });

      return jsonResponse({
        recommendations: serializeRecommendations(recommendations),
        source: "gemini",
      });
    } catch (error) {
      console.warn(
        `Gemini reranking failed; using deterministic fallback: ${
          String(error)
        }`,
      );
      const fallback = buildDeterministicFallbackResponse(top20Candidates);
      const fallbackRecommendations = buildDeterministicFallbackRecommendations(
        top20Candidates,
      );
      await saveRecommendationResults({
        supabase: persistenceClient,
        userId: user.id,
        recommendations: fallbackRecommendations,
        modelName: "deterministic_fallback",
      });
      return jsonResponse(fallback);
    }
  } catch (error) {
    return jsonResponse({ error: String(error) }, 500);
  }
});
