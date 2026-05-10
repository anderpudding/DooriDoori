# DooriDoori MVP Mock Data Schema Notes

This normalized dataset is intended for the Core MVP Personal Page recommendation feed.

## Main changes from original files

- Normalized category values to `food`, `events`, and `lifestyle`.
- Added `type` to distinguish content nature: `place`, `event`, or `lifestyle`.
- Added `city` and `district`.
- Converted `priceTier` into numeric `priceLevel`.
- Added `koreanRelevanceTags`.
- Added `sourceType`, `dataQuality`, `popularityScore`, `freshnessScore`, `isActive`, `createdAt`, and `updatedAt`.
- Preserved category-specific fields inside `metadata`.
- Kept `rating` and `reviewCount` as `null` for future Google Places display metadata.

## Recommendation-use fields

Use these first for Core MVP scoring:

- `category`
- `district`
- `priceLevel`
- `vibeTags`
- `koreanRelevanceTags`
- `popularityScore`
- `freshnessScore`
- `isActive`

## Notes

- This is mock/manual data. Real-world venue/event accuracy has not been verified.
- Do not use Google review text or scraped reviews in this MVP dataset.
- `whyRecommended` is intentionally not stored. Generate it dynamically from matched fields.
