import Foundation
import Testing
@testable import DooriDoori

struct DooriDooriTests {
    @Test func reviewedSeedDataDecodesAndUsesNormalizedCategories() throws {
        let data = try Data(contentsOf: reviewedDataURL())
        let items = try JSONDecoder().decode([ContentItem].self, from: data)

        #expect(items.count == 30)
        #expect(Set(items.map(\.category.rawValue)) == ["food", "events", "lifestyle"])
        let allItemsAreActive = items.allSatisfy { $0.isActive }
        #expect(allItemsAreActive)
    }

    @Test func recommendationsRankCategoryDistrictVibeAndBudgetMatches() {
        let service = RecommendationService()
        let preference = UserPreference(
            selectedCategories: ["food"],
            preferredDistricts: ["Coquitlam"],
            budgetLevel: 2,
            vibeTags: ["cozy", "newcomer-friendly"],
            infoNeeds: [],
            languagePreference: .both,
            updatedAt: Date()
        )

        let strongMatch = makeItem(
            id: "strong",
            category: .food,
            district: "Coquitlam",
            priceLevel: 2,
            vibeTags: ["cozy"],
            koreanRelevanceTags: ["korean-friendly", "newcomer-friendly"]
        )
        let weakMatch = makeItem(
            id: "weak",
            category: .lifestyle,
            district: "Yaletown",
            priceLevel: 4,
            vibeTags: ["formal"],
            koreanRelevanceTags: []
        )

        let ranked = service.rankedItems(for: preference, items: [weakMatch, strongMatch])

        #expect(ranked.first?.item.id == "strong")
        #expect((ranked.first?.score ?? 0) > (ranked.last?.score ?? 0))
        #expect(ranked.first?.reason.contains("Coquitlam") == true)
    }

    @Test func storesPersistPreferencesAndSavedIDs() {
        let suiteName = "dooridoori.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let preferenceStore = PreferenceStore(defaults: defaults, key: "pref")
        let preference = UserPreference(
            selectedCategories: ["events"],
            preferredDistricts: ["Burnaby"],
            budgetLevel: 1,
            vibeTags: ["free-entry"],
            infoNeeds: ["events"],
            languagePreference: .ko,
            updatedAt: Date()
        )
        preferenceStore.save(preference)

        let reloadedPreferenceStore = PreferenceStore(defaults: defaults, key: "pref")
        #expect(reloadedPreferenceStore.preference.selectedCategories == ["events"])
        #expect(reloadedPreferenceStore.preference.preferredDistricts == ["Burnaby"])

        let savedStore = SavedItemStore(defaults: defaults, key: "saved")
        let item = makeItem(id: "saved-id")
        savedStore.toggle(item)

        let reloadedSavedStore = SavedItemStore(defaults: defaults, key: "saved")
        #expect(reloadedSavedStore.isSaved(item))
    }

    private func reviewedDataURL() throws -> URL {
        let testFileURL = URL(fileURLWithPath: #filePath)
        let repoRoot = testFileURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let url = repoRoot
            .appendingPathComponent("DooriDoori")
            .appendingPathComponent("dooridoori_reviewed_mock_data")
            .appendingPathComponent("dooridoori_mvp_content_items.json")
        #expect(FileManager.default.fileExists(atPath: url.path))
        return url
    }

    private func makeItem(
        id: String = "item",
        category: ContentCategory = .food,
        district: String = "Coquitlam",
        priceLevel: Int = 2,
        vibeTags: [String] = ["cozy"],
        koreanRelevanceTags: [String] = ["korean-friendly"],
        isActive: Bool = true
    ) -> ContentItem {
        ContentItem(
            id: id,
            type: category == .events ? .event : .place,
            category: category,
            subcategoryContent: "restaurant",
            subcategoryDisplayKr: "식당",
            nameEn: "Sample",
            nameKr: "샘플",
            description: "A local pick.",
            city: "Coquitlam",
            district: district,
            address: "123 Sample St",
            coordinates: Coordinates(lat: 49.0, lng: -123.0),
            imageURL: nil,
            priceTier: priceLevel == 0 ? "Free" : String(repeating: "$", count: priceLevel),
            priceLevel: priceLevel,
            vibeTags: vibeTags,
            koreanRelevanceTags: koreanRelevanceTags,
            schedule: ContentSchedule(type: .recurring, openingHours: "Mon-Sun 9:00-18:00", startDateTime: nil, endDateTime: nil),
            dimensionScores: ["value": 4],
            sourceType: .manual,
            popularityScore: 0.8,
            freshnessScore: 0.7,
            isActive: isActive,
            rating: nil,
            reviewCount: nil,
            createdAt: nil,
            updatedAt: nil
        )
    }
}
