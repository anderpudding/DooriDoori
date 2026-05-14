# DooriDoori

KDD AI Project Study Group 2

## Phase 2: Onboarding Preferences

Onboarding preferences are stored in `public.user_preferences` with one row per
Supabase Auth user. The iOS app signs in through Supabase, uses the authenticated
`user_id`, and upserts:

- `preferred_categories`
- `preferred_areas`
- `budget_level`
- `vibe_tags`
- `activity_tags`
- `language_preference`
- `travel_preference`
- `negative_tags`
- `onboarding_completed`

If a preference row exists, the app can load it back into the local
`PreferenceStore`. If no row exists, the app routes the user to onboarding or
uses safe local defaults while onboarding is shown.

## Phase 3/4: Recommendations

`recommend-for-user` keeps deterministic scoring as the candidate generator, then
uses Gemini only for Phase 4 reranking. It:

1. Requires an authenticated Supabase user.
2. Loads the current user's `user_preferences`.
3. Loads only active and approved `content_items`.
4. Applies basic pre-filtering.
5. Calculates normalized deterministic scores.
6. Selects up to 20 deterministic candidates sorted by `deterministicScore`.
7. Sends only compact structured metadata for those candidates to Gemini.
8. Validates Gemini output strictly and returns final Top 5 recommendations.

Gemini never creates new content. It may only choose ids from the deterministic
Top 20, and the function falls back to deterministic Top 5 if Gemini is missing,
slow, unavailable, or invalid.

Required secret:

- `GEMINI_API_KEY`

Optional secret:

- `GEMINI_MODEL=gemini-2.5-flash-lite`

### Local Edge Function

Create `supabase/.env`:

```sh
SUPABASE_URL=your_supabase_project_url
SUPABASE_ANON_KEY=your_supabase_anon_key
SUPABASE_SERVICE_ROLE_KEY=your_service_role_key_optional_for_result_writes
GEMINI_API_KEY=your_gemini_api_key
GEMINI_MODEL=gemini-2.5-flash-lite
```

Serve locally:

```sh
supabase functions serve recommend-for-user --env-file supabase/.env
```

Run Edge Function tests if Deno is installed:

```sh
deno test --allow-net supabase/functions/recommend-for-user
```

Example request:

```sh
curl -i \
  -H "Authorization: Bearer $SUPABASE_ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  http://127.0.0.1:54321/functions/v1/recommend-for-user
```

Expected response shape:

```json
{
  "recommendations": [
    {
      "content": {
        "id": "...",
        "title": "...",
        "type": "place",
        "category": "food",
        "subcategories": [],
        "area": "burnaby",
        "city": "Burnaby",
        "budgetLevel": "medium",
        "vibeTags": [],
        "activityTags": [],
        "shortDescription": "...",
        "imageUrl": "..."
      },
      "finalScore": 0.91,
      "deterministicScore": 0.82,
      "rank": 1,
      "reason": "Matches your preference for cozy Korean-friendly cafes in Burnaby.",
      "confidence": 0.87,
      "modelName": "gemini-2.5-flash-lite",
      "scoreBreakdown": {
        "deterministicScore": 0.82,
        "categoryMatch": 1,
        "vibeMatch": 0.75,
        "locationMatch": 1,
        "budgetMatch": 0.6,
        "contentQuality": 0.84,
        "engagementScore": 0.32,
        "freshnessOrDiversity": 0.5,
        "geminiRank": 1,
        "geminiConfidence": 0.87
      }
    }
  ],
  "metadata": {
    "candidateCount": 20,
    "returnedCount": 5,
    "usedGemini": true,
    "phase": "gemini_reranking",
    "modelName": "gemini-2.5-flash-lite"
  }
}
```

If fallback is used, `metadata.usedGemini` is `false` and `metadata.modelName`
is `deterministic_fallback`. The fallback response still returns valid Top 5
recommendations with deterministic template reasons.
