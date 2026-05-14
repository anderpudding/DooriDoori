# DooriDoori
KDD AI Project Study Group 2

## Supabase Edge Function Gemini setup

`recommend-for-user` builds deterministic recommendation scores first, keeps only
the Top 20 compact candidates, and then asks Gemini to rerank those candidates
into a final Top 5. Gemini never creates new content: the Edge Function validates
that every returned id exists in the deterministic Top 20 and falls back to the
deterministic Top 5 if Gemini is unavailable or returns invalid output.

The Gemini payload only includes structured `content_items` metadata and
`user_preferences`. It does not send Google review text, external scraped review
text, raw external API data, or embedding similarity data.

Required secret:

- `GEMINI_API_KEY`

Optional secret:

- `GEMINI_MODEL=gemini-2.5-flash-lite`

Local development:

1. Create `supabase/.env`.
2. Add `GEMINI_API_KEY=...`.
3. Optionally add `GEMINI_MODEL=gemini-2.5-flash-lite`.
4. Run `supabase functions serve recommend-for-user --env-file supabase/.env`.

Local tests:

```sh
deno test --allow-net supabase/functions/recommend-for-user
```

Example local request:

```sh
curl -i \
  -H "Authorization: Bearer $SUPABASE_ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  http://127.0.0.1:54321/functions/v1/recommend-for-user
```

Production:

1. Run `supabase secrets set GEMINI_API_KEY=...`.
2. Optionally run `supabase secrets set GEMINI_MODEL=gemini-2.5-flash-lite`.
3. Run `supabase functions deploy recommend-for-user`.

Do not put `GEMINI_API_KEY` in the iOS app, Xcode config, `Info.plist`, or Swift files.
