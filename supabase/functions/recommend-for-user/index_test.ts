import {
  assertEquals,
  assertThrows,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  buildDeterministicFallbackRecommendations,
  buildRecommendationResultRows,
  buildRerankedRecommendations,
  parseGeminiRerankJson,
  validateAndMergeGeminiResults,
} from "./index.ts";

function candidate(id: string, score: number) {
  return {
    id,
    title: `Item ${id}`,
    type: "place",
    category: "food",
    subcategories: ["cafe"],
    area: "Burnaby",
    city: "Burnaby",
    budget_level: "medium",
    vibe_tags: ["cozy"],
    activity_tags: ["coffee"],
    short_description: "A short description.",
    image_url: null,
    quality_score: 0.8,
    korean_community_fit: 0.9,
    view_count: 10,
    save_count: 3,
    review_count: 2,
    average_rating: 4.5,
    created_at: "2026-05-01T00:00:00.000Z",
    deterministic_score: score,
    score_breakdown: {
      categoryMatch: 1,
      vibeMatch: 1,
      activityMatch: 1,
      locationMatch: 1,
      budgetMatch: 1,
      contentQuality: 0.8,
      engagementScore: 0.4,
      koreanCommunityFit: 0.9,
      freshnessOrDiversity: 0.7,
    },
  } as any;
}

const top20 = Array.from({ length: 6 }, (_, index) =>
  candidate(`content-${index + 1}`, 0.9 - index * 0.05)
);

Deno.test("valid Gemini output maps to sorted Top 5", () => {
  const recommendations = validateAndMergeGeminiResults({
    top20Candidates: top20,
    modelName: "gemini-2.5-flash-lite",
    geminiResult: {
      rankedItems: [
        {
          id: "content-2",
          rank: 2,
          reason: "A strong nearby Korean-friendly cafe match.",
          confidence: 0.8,
        },
        {
          id: "content-1",
          rank: 1,
          reason: "Best fit for your cozy cafe preferences.",
          confidence: 0.9,
        },
        {
          id: "content-3",
          rank: 3,
          reason: "Matches your food and activity preferences.",
          confidence: 0.7,
        },
        {
          id: "content-4",
          rank: 4,
          reason: "Good budget and area fit.",
          confidence: 0.6,
        },
        {
          id: "content-5",
          rank: 5,
          reason: "Relevant option for your selected vibe.",
          confidence: 0.5,
        },
      ],
    },
  });

  assertEquals(recommendations.map((item) => item.id), [
    "content-1",
    "content-2",
    "content-3",
    "content-4",
    "content-5",
  ]);
  assertEquals(recommendations[0].confidence, 0.9);
  assertEquals(recommendations[0].model_name, "gemini-2.5-flash-lite");
  assertEquals(recommendations[0].stored_score_breakdown.geminiRank, 1);
});

Deno.test("Gemini id outside candidates is rejected", () => {
  assertThrows(
    () =>
      validateAndMergeGeminiResults({
        top20Candidates: top20,
        modelName: "gemini-2.5-flash-lite",
        geminiResult: {
          rankedItems: [
            {
              id: "not-a-candidate",
              rank: 1,
              reason: "Looks relevant.",
              confidence: 0.8,
            },
            {
              id: "content-2",
              rank: 2,
              reason: "Looks relevant.",
              confidence: 0.8,
            },
            {
              id: "content-3",
              rank: 3,
              reason: "Looks relevant.",
              confidence: 0.8,
            },
            {
              id: "content-4",
              rank: 4,
              reason: "Looks relevant.",
              confidence: 0.8,
            },
            {
              id: "content-5",
              rank: 5,
              reason: "Looks relevant.",
              confidence: 0.8,
            },
          ],
        },
      }),
    Error,
    "unknown candidate id",
  );
});

Deno.test("duplicate Gemini ids are rejected", () => {
  assertThrows(
    () =>
      validateAndMergeGeminiResults({
        top20Candidates: top20,
        modelName: "gemini-2.5-flash-lite",
        geminiResult: {
          rankedItems: [
            {
              id: "content-1",
              rank: 1,
              reason: "Looks relevant.",
              confidence: 0.8,
            },
            {
              id: "content-1",
              rank: 2,
              reason: "Looks relevant.",
              confidence: 0.8,
            },
            {
              id: "content-3",
              rank: 3,
              reason: "Looks relevant.",
              confidence: 0.8,
            },
            {
              id: "content-4",
              rank: 4,
              reason: "Looks relevant.",
              confidence: 0.8,
            },
            {
              id: "content-5",
              rank: 5,
              reason: "Looks relevant.",
              confidence: 0.8,
            },
          ],
        },
      }),
    Error,
    "duplicate id",
  );
});

Deno.test("invalid JSON is rejected for fallback handling", () => {
  assertThrows(
    () => parseGeminiRerankJson("{bad json"),
    Error,
    "Failed to parse Gemini JSON response",
  );
});

Deno.test("missing Gemini API key fallback returns deterministic Top 5", () => {
  const fallback = buildDeterministicFallbackRecommendations(top20);

  assertEquals(fallback.length, 5);
  assertEquals(fallback.map((item) => item.id), [
    "content-1",
    "content-2",
    "content-3",
    "content-4",
    "content-5",
  ]);
  assertEquals(fallback[0].model_name, "deterministic_fallback");
  assertEquals(fallback[0].confidence, null);
});

Deno.test("missing GEMINI_API_KEY path does not call Gemini", async () => {
  const outcome = await buildRerankedRecommendations({
    geminiApiKey: undefined,
    geminiModel: "gemini-2.5-flash-lite",
    prefs: {
      preferred_categories: ["food"],
      preferred_areas: ["Burnaby"],
      budget_level: "medium",
      vibe_tags: ["cozy"],
      activity_tags: ["coffee"],
      language_preference: "korean_friendly",
      travel_preference: "any",
      negative_tags: [],
    },
    top20Candidates: top20,
  });

  assertEquals(outcome.usedGemini, false);
  assertEquals(outcome.modelName, "deterministic_fallback");
  assertEquals(outcome.fallbackReason, "missing_gemini_api_key");
  assertEquals(outcome.recommendations.map((item) => item.id), [
    "content-1",
    "content-2",
    "content-3",
    "content-4",
    "content-5",
  ]);
});

Deno.test("recommendation_results payload includes reason and model_name", () => {
  const fallback = buildDeterministicFallbackRecommendations(top20);
  const rows = buildRecommendationResultRows({
    userId: "user-1",
    recommendations: fallback,
    generatedAt: "2026-05-14T12:00:00.000Z",
  });

  assertEquals(rows.length, 5);
  assertEquals(rows[0].reason, fallback[0].reason);
  assertEquals(rows[0].model_name, "deterministic_fallback");
  assertEquals(rows[0].score_breakdown.deterministicScore, 0.9);
});
