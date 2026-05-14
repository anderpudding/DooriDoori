# DooriDoori
KDD AI Project Study Group 2

## Supabase Edge Function Gemini setup

Local development:

1. Create `supabase/.env`.
2. Add `GEMINI_API_KEY=...`.
3. Run `supabase functions serve recommend-for-user --env-file supabase/.env`.

Production:

1. Run `supabase secrets set GEMINI_API_KEY=...`.
2. Run `supabase functions deploy recommend-for-user`.

Do not put `GEMINI_API_KEY` in the iOS app, Xcode config, `Info.plist`, or Swift files.
