import {
  assertEquals,
  assertThrows,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  buildDeterministicFallbackRecommendations,
  buildRecommendationResultRows,
  buildRerankedRecommendations,
  calculateDeterministicScore,
  parseGeminiRerankJson,
  selectTopCandidates,
  validateAndMergeGeminiResults,
} from "./index.ts";

function content(overrides: Record<string, unknown> = {}) {
  return {
    id: String(overrides.id ?? crypto.randomUUID()),
    title: overrides.title ?? "Cafe",
    type: overrides.type ?? "place",
    category: overrides.category ?? "food",
    subcategories: overrides.subcategories ?? ["cafe"],
    area: overrides.area ?? "burnaby",
    city: overrides.city ?? "Burnaby",
    budget_level: overrides.budget_level ?? "medium",
    vibe_tags: overrides.vibe_tags ?? ["cozy", "study_friendly"],
    activity_tags: overrides.activity_tags ?? ["coffee"],
    short_description: overrides.short_description ?? "A short description.",
    image_url: overrides.image_url ?? "/mock/image.jpg",
    quality_score: overrides.quality_score ?? 0.8,
    korean_community_fit: overrides.korean_community_fit ?? 0.9,
    view_count: overrides.view_count ?? 20,
    save_count: overrides.save_count ?? 5,
    review_count: overrides.review_count ?? 2,
    average_rating: overrides.average_rating ?? 4.4,
    is_active: overrides.is_active ?? true,
    is_approved: overrides.is_approved ?? true,
    created_at: overrides.created_at ?? "2026-05-01T00:00:00.000Z",
  } as any;
}

const prefs = {
  preferred_categories: ["food"],
  preferred_areas: ["burnaby"],
  budget_level: "medium",
  vibe_tags: ["cozy", "quiet"],
  activity_tags: [],
  language_preference: "korean_friendly",
  travel_preference: "any",
  negative_tags: [],
} as any;

function topCandidates(count = 6) {
  return selectTopCandidates({
    prefs,
    items: Array.from({ length: count }, (_, index) =>
      content({
        id: `item-${index + 1}`,
        save_count: count - index,
        quality_score: 0.9 - index / 100,
      })
    ),
  });
}

Deno.test("selectTopCandidates excludes inactive and unapproved content", () => {
  const candidates = selectTopCandidates({
    prefs,
    items: [
      content({ id: "active-approved" }),
      content({ id: "inactive", is_active: false }),
      content({ id: "unapproved", is_approved: false }),
    ],
  });

  assertEquals(candidates.map((item) => item.id), ["active-approved"]);
});

Deno.test("score breakdown and deterministic score stay between 0 and 1", () => {
  const [candidate] = selectTopCandidates({
    prefs,
    items: [
      content({
        quality_score: 4,
        korean_community_fit: -1,
        save_count: 9_999,
        view_count: 50_000,
      }),
    ],
  });
  const score = calculateDeterministicScore(prefs, candidate);

  assertEquals(score.recommendationScore >= 0, true);
  assertEquals(score.recommendationScore <= 1, true);

  for (const value of Object.values(score.scoreBreakdown)) {
    assertEquals(value >= 0, true);
    assertEquals(value <= 1, true);
  }
});

Deno.test("candidates sort by deterministicScore descending and cap at 20", () => {
  const items = Array.from({ length: 25 }, (_, index) =>
    content({
      id: `item-${index}`,
      save_count: index,
      view_count: index * 10,
      quality_score: 0.5 + index / 100,
    })
  );
  const candidates = selectTopCandidates({ prefs, items });

  assertEquals(candidates.length, 20);
  for (let index = 1; index < candidates.length; index += 1) {
    assertEquals(
      candidates[index - 1].recommendation_score >=
        candidates[index].recommendation_score,
      true,
    );
  }
});

Deno.test("empty preference arrays do not crash scoring", () => {
  const candidates = selectTopCandidates({
    prefs: {
      ...prefs,
      preferred_categories: [],
      preferred_areas: [],
      vibe_tags: [],
    },
    items: [content({ id: "safe-defaults" })],
  });

  assertEquals(candidates.length, 1);
  assertEquals(candidates[0].score_breakdown.categoryMatch, 0.5);
  assertEquals(candidates[0].score_breakdown.vibeMatch, 0.5);
  assertEquals(candidates[0].score_breakdown.locationMatch, 0.5);
});

Deno.test("missing optional content fields do not crash candidate selection", () => {
  const candidates = selectTopCandidates({
    prefs,
    items: [
      content({
        id: "optional-fields-missing",
        image_url: null,
        subcategories: null,
        vibe_tags: null,
        activity_tags: null,
        average_rating: null,
      }),
    ],
  });

  assertEquals(candidates.length, 1);
  assertEquals(candidates[0].image_url, null);
});

Deno.test("valid Gemini output returns Top 5 sorted by rank", () => {
  const candidates = topCandidates();
  const recommendations = validateAndMergeGeminiResults({
    top20Candidates: candidates,
    modelName: "gemini-2.5-flash-lite",
    geminiResult: {
      rankedItems: [
        {
          id: "item-2",
          rank: 2,
          reason: "Good cozy cafe fit in Burnaby.",
          confidence: 0.8,
        },
        {
          id: "item-1",
          rank: 1,
          reason: "Strong match for Korean-friendly cozy cafes.",
          confidence: 0.9,
        },
        {
          id: "item-3",
          rank: 3,
          reason: "Matches your food and vibe preferences.",
          confidence: 0.7,
        },
        {
          id: "item-4",
          rank: 4,
          reason: "Relevant nearby pick for your budget.",
          confidence: 0.6,
        },
        {
          id: "item-5",
          rank: 5,
          reason: "Good option for a cozy local outing.",
          confidence: 0.5,
        },
      ],
    },
  });

  assertEquals(recommendations.map((item) => item.id), [
    "item-1",
    "item-2",
    "item-3",
    "item-4",
    "item-5",
  ]);
  assertEquals(recommendations[0].confidence, 0.9);
  assertEquals(recommendations[0].model_name, "gemini-2.5-flash-lite");
  assertEquals(recommendations[0].stored_score_breakdown.geminiRank, 1);
});

Deno.test("Gemini id outside candidates is rejected", () => {
  const candidates = topCandidates();

  assertThrows(
    () =>
      validateAndMergeGeminiResults({
        top20Candidates: candidates,
        modelName: "gemini-2.5-flash-lite",
        geminiResult: {
          rankedItems: [
            {
              id: "not-a-candidate",
              rank: 1,
              reason: "Looks relevant.",
              confidence: 0.8,
            },
            ...[2, 3, 4, 5].map((rank) => ({
              id: `item-${rank}`,
              rank,
              reason: "Looks relevant.",
              confidence: 0.8,
            })),
          ],
        },
      }),
    Error,
    "unknown candidate id",
  );
});

Deno.test("duplicate Gemini ids are rejected", () => {
  const candidates = topCandidates();

  assertThrows(
    () =>
      validateAndMergeGeminiResults({
        top20Candidates: candidates,
        modelName: "gemini-2.5-flash-lite",
        geminiResult: {
          rankedItems: [
            {
              id: "item-1",
              rank: 1,
              reason: "Looks relevant.",
              confidence: 0.8,
            },
            {
              id: "item-1",
              rank: 2,
              reason: "Looks relevant.",
              confidence: 0.8,
            },
            ...[3, 4, 5].map((rank) => ({
              id: `item-${rank}`,
              rank,
              reason: "Looks relevant.",
              confidence: 0.8,
            })),
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

Deno.test("invalid JSON falls back through rerank path", async () => {
  const outcome = await buildRerankedRecommendations({
    geminiApiKey: "test-key",
    geminiModel: "gemini-2.5-flash-lite",
    prefs,
    top20Candidates: topCandidates(),
    reranker: () => Promise.resolve(parseGeminiRerankJson("{bad json")),
  });

  assertEquals(outcome.usedGemini, false);
  assertEquals(outcome.modelName, "deterministic_fallback");
  assertEquals(outcome.recommendations.length, 5);
});

Deno.test("missing GEMINI_API_KEY falls back", async () => {
  const outcome = await buildRerankedRecommendations({
    geminiApiKey: undefined,
    geminiModel: "gemini-2.5-flash-lite",
    prefs,
    top20Candidates: topCandidates(),
  });

  assertEquals(outcome.usedGemini, false);
  assertEquals(outcome.modelName, "deterministic_fallback");
  assertEquals(outcome.recommendations.length, 5);
});

Deno.test("Gemini timeout or request failure falls back", async () => {
  const outcome = await buildRerankedRecommendations({
    geminiApiKey: "test-key",
    geminiModel: "gemini-2.5-flash-lite",
    prefs,
    top20Candidates: topCandidates(),
    reranker: () => Promise.reject(new Error("The operation timed out")),
  });

  assertEquals(outcome.usedGemini, false);
  assertEquals(outcome.modelName, "deterministic_fallback");
  assertEquals(outcome.fallbackReason, "The operation timed out");
});

Deno.test("deterministic fallback returns valid Top 5", () => {
  const fallback = buildDeterministicFallbackRecommendations(topCandidates());

  assertEquals(fallback.length, 5);
  assertEquals(fallback[0].model_name, "deterministic_fallback");
  assertEquals(fallback[0].confidence, null);
  assertEquals(fallback[0].stored_score_breakdown.fallback, true);
});

Deno.test("recommendation_results rows include reason and model_name", () => {
  const fallback = buildDeterministicFallbackRecommendations(topCandidates());
  const rows = buildRecommendationResultRows({
    userId: "user-1",
    recommendations: fallback,
    generatedAt: "2026-05-14T12:00:00.000Z",
  });

  assertEquals(rows.length, 5);
  assertEquals(rows[0].reason, fallback[0].reason);
  assertEquals(rows[0].model_name, "deterministic_fallback");
  assertEquals(rows[0].score_breakdown.fallback, true);
});

Deno.test("endpoint helpers work with fewer than 5 candidates", async () => {
  const candidates = topCandidates(3);
  const outcome = await buildRerankedRecommendations({
    geminiApiKey: "test-key",
    geminiModel: "gemini-2.5-flash-lite",
    prefs,
    top20Candidates: candidates,
    reranker: () =>
      Promise.resolve({
        rankedItems: candidates.map((candidate, index) => ({
          id: candidate.id,
          rank: index + 1,
          reason: "Relevant local pick for your preferences.",
          confidence: 0.7,
        })),
      }),
  });

  assertEquals(outcome.usedGemini, true);
  assertEquals(outcome.recommendations.length, 3);
});
