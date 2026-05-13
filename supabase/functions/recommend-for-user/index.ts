import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

type ContentItem = {
  id: string;
  title: string;
  type: "place" | "event" | "lifestyle";
  category: "food" | "events" | "lifestyle";
  subcategories: string[];
  area: string;
  budget_level: "low" | "medium" | "high" | "any";
  vibe_tags: string[];
  activity_tags: string[];
  short_description: string | null;
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
  negative_tags: string[];
};

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
  const raw =
    Math.log1p(item.save_count) * 0.6 +
    Math.log1p(item.review_count) * 0.25 +
    Math.log1p(item.view_count) * 0.15;

  return Math.min(raw / 5, 1);
}

function freshnessDiversityScore(item: ContentItem): number {
  const created = new Date(item.created_at).getTime();
  const now = Date.now();
  const ageDays = (now - created) / (1000 * 60 * 60 * 24);

  if (ageDays <= 7) return 1;
  if (ageDays <= 30) return 0.7;
  if (ageDays <= 90) return 0.4;
  return 0.2;
}

function calculateScore(prefs: UserPreferences, item: ContentItem) {
  const scores = {
    categoryMatch: categoryMatch(prefs, item),
    vibeMatch: overlapRatio(prefs.vibe_tags, item.vibe_tags),
    locationMatch: locationMatch(prefs, item),
    budgetMatch: budgetMatch(prefs, item),
    contentQuality: Number(item.quality_score ?? 0),
    engagementScore: engagementScore(item),
    freshnessOrDiversity: freshnessDiversityScore(item),
  };

  const finalScore =
    0.25 * scores.categoryMatch +
    0.20 * scores.vibeMatch +
    0.15 * scores.locationMatch +
    0.10 * scores.budgetMatch +
    0.15 * scores.contentQuality +
    0.10 * scores.engagementScore +
    0.05 * scores.freshnessOrDiversity;

  return {
    finalScore,
    scoreBreakdown: scores,
  };
}

serve(async (req) => {
  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY")!;

    const authHeader = req.headers.get("Authorization");

    if (!authHeader) {
      return new Response(JSON.stringify({ error: "Missing Authorization header" }), {
        status: 401,
        headers: { "Content-Type": "application/json" },
      });
    }

    const supabase = createClient(supabaseUrl, supabaseAnonKey, {
      global: {
        headers: {
          Authorization: authHeader,
        },
      },
    });

    const {
      data: { user },
      error: userError,
    } = await supabase.auth.getUser();

    if (userError || !user) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: { "Content-Type": "application/json" },
      });
    }

    const { data: prefs, error: prefsError } = await supabase
      .from("user_preferences")
      .select("*")
      .eq("user_id", user.id)
      .single();

    if (prefsError || !prefs) {
      return new Response(JSON.stringify({ error: "User preferences not found" }), {
        status: 404,
        headers: { "Content-Type": "application/json" },
      });
    }

    const { data: items, error: itemsError } = await supabase
      .from("content_items")
      .select("*")
      .eq("is_active", true)
      .eq("is_approved", true);

    if (itemsError) {
      return new Response(JSON.stringify({ error: itemsError.message }), {
        status: 500,
        headers: { "Content-Type": "application/json" },
      });
    }

    const candidates = (items as ContentItem[])
      .filter((item) => item.quality_score >= 0.5)
      .filter((item) => item.short_description && item.short_description.length > 0)
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

    return new Response(JSON.stringify({ candidates }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  } catch (error) {
    return new Response(JSON.stringify({ error: String(error) }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});