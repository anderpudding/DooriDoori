import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  buildRecommendationResultRows,
  calculateDeterministicScore,
  selectTopCandidates,
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

Deno.test("recommendation_results rows are deterministic_v1", () => {
  const candidates = selectTopCandidates({
    prefs,
    items: [content({ id: "result-row" })],
  });
  const rows = buildRecommendationResultRows({
    userId: "user-1",
    candidates,
    generatedAt: "2026-05-14T12:00:00.000Z",
  });

  assertEquals(rows[0].model_name, "deterministic_v1");
  assertEquals(rows[0].gemini_confidence, null);
  assertEquals(rows[0].final_score, candidates[0].recommendation_score);
});
