import Foundation

struct RankedContentItem: Identifiable, Hashable {
    let item: ContentItem
    let score: Double
    let reason: String

    var id: String { item.id }
}

struct RecommendationService {
    private let koreanSignalTags: Set<String> = [
        "korean-community",
        "korean-friendly",
        "newcomer-friendly",
        "curated-for-vancouver-koreans"
    ]

    func rankedItems(
        for preference: UserPreference,
        items: [ContentItem],
        categoryFilter: ContentCategory? = nil
    ) -> [RankedContentItem] {
        items
            .filter(\.isActive)
            .filter { item in
                guard let categoryFilter else { return true }
                return item.category == categoryFilter
            }
            .map { item in
                RankedContentItem(
                    item: item,
                    score: score(item: item, preference: preference),
                    reason: reason(item: item, preference: preference)
                )
            }
            .sorted {
                if $0.score == $1.score {
                    return $0.item.popularityScore > $1.item.popularityScore
                }
                return $0.score > $1.score
            }
    }

    func score(item: ContentItem, preference: UserPreference) -> Double {
        let selectedCategories = Set(preference.selectedCategories)
        let preferredDistricts = Set(preference.preferredDistricts.map(normalize))
        let preferredVibes = Set(preference.vibeTags)
        let itemVibes = Set(item.vibeTags)
        let itemKoreanTags = Set(item.koreanRelevanceTags)

        let categoryMatch = selectedCategories.contains(item.category.rawValue) ? 1.0 : 0.0
        let districtMatch = preferredDistricts.contains(normalize(item.district)) ? 1.0 : 0.0

        let vibeOverlap = preferredVibes.intersection(itemVibes).count
        let vibeMatch = preferredVibes.isEmpty ? 0.0 : Double(vibeOverlap) / Double(preferredVibes.count)

        let budgetMatch: Double
        if item.priceLevel <= preference.budgetLevel {
            budgetMatch = 1.0
        } else {
            budgetMatch = max(0.0, 1.0 - Double(item.priceLevel - preference.budgetLevel) * 0.25)
        }

        let koreanRelevanceScore = min(1.0, Double(itemKoreanTags.intersection(koreanSignalTags).count) / 2.0)

        return categoryMatch * 30
            + districtMatch * 20
            + vibeMatch * 20
            + budgetMatch * 10
            + koreanRelevanceScore * 10
            + item.popularityScore * 5
            + item.freshnessScore * 5
    }

    func reason(item: ContentItem, preference: UserPreference) -> String {
        var parts: [String] = []

        if preference.selectedCategories.contains(item.category.rawValue) {
            parts.append(item.category.titleEn)
        }

        if preference.preferredDistricts.map(normalize).contains(normalize(item.district)) {
            parts.append(item.district)
        }

        let matchedVibes = item.vibeTags.filter { preference.vibeTags.contains($0) }
        if let vibe = matchedVibes.first {
            parts.append(vibe.replacingOccurrences(of: "-", with: " "))
        }

        if item.koreanRelevanceTags.contains(where: { koreanSignalTags.contains($0) }) {
            parts.append("Korean-friendly")
        }

        if parts.isEmpty {
            return "Recommended from curated Vancouver picks for Korean residents."
        }

        let summary = parts.prefix(3).joined(separator: ", ")
        return "Recommended because it matches \(summary)."
    }

    private func normalize(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
