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

## Phase 3: Deterministic Recommendations

`recommend-for-user` is deterministic-only in Phase 3. It:

1. Requires an authenticated Supabase user.
2. Loads the current user's `user_preferences`.
3. Loads only active and approved `content_items`.
4. Applies basic pre-filtering.
5. Calculates normalized deterministic scores.
6. Returns up to 20 candidates sorted by `deterministicScore`.

Gemini reranking is Phase 4 and is intentionally not called by this function.

### Local Edge Function

Create `supabase/.env`:

```sh
SUPABASE_URL=your_supabase_project_url
SUPABASE_ANON_KEY=your_supabase_anon_key
SUPABASE_SERVICE_ROLE_KEY=your_service_role_key_optional_for_result_writes
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
  "candidates": [
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
      "deterministicScore": 0.82,
      "rank": 1,
      "reason": "Recommended because it matches your food preferences in burnaby.",
      "modelName": "deterministic_v1",
      "scoreBreakdown": {
        "categoryMatch": 1,
        "vibeMatch": 0.75,
        "locationMatch": 1,
        "budgetMatch": 0.6,
        "contentQuality": 0.84,
        "engagementScore": 0.32,
        "freshnessOrDiversity": 0.5
      }
    }
  ],
  "metadata": {
    "candidateCount": 20,
    "returnedCount": 20,
    "usedGemini": false,
    "phase": "deterministic_scoring",
    "modelName": "deterministic_v1"
  }
}
```

The response also includes a `recommendations` key with the same array for
compatibility with the current iOS decoder.
