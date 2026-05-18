import Foundation
import Testing
@testable import DooriDoori

struct DooriDooriTests {
    @Test func reviewedSeedDataDecodesAndUsesNormalizedCategories() throws {
        let items = try reviewedItems()

        #expect(items.count == 30)
        #expect(Set(items.map(\.category.rawValue)) == ["food", "events", "lifestyle"])
        #expect(items.filter { $0.type == .event }.allSatisfy { $0.category.rawValue != "event" })
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

    @Test func supabaseRecommendationResponseDecodesPhase4RecommendationPayload() throws {
        let json = """
        {
          "recommendations": [
            {
              "content": {
                "id": "11111111-1111-1111-1111-111111111111",
                "title": "Rice Workshop",
                "type": "place",
                "category": "food",
                "subcategories": ["restaurant"],
                "area": "Burnaby",
                "city": "Burnaby",
                "budgetLevel": "medium",
                "vibeTags": ["cozy"],
                "activityTags": ["dinner"],
                "shortDescription": "Comforting Korean food.",
                "imageUrl": null
              },
              "rank": 1,
              "reason": "Matches your preference for cozy Korean-friendly cafes in Burnaby.",
              "finalScore": 0.94,
              "deterministicScore": 0.82,
              "confidence": 0.87,
              "modelName": "gemini-2.5-flash-lite",
              "scoreBreakdown": {
                "deterministicScore": 0.82,
                "categoryMatch": 1,
                "vibeMatch": 1,
                "locationMatch": 0.5,
                "budgetMatch": 1,
                "contentQuality": 0.86,
                "engagementScore": 0.3,
                "koreanCommunityFit": 0.9,
                "freshnessOrDiversity": 1,
                "geminiRank": 1,
                "geminiConfidence": 0.87
              }
            }
          ],
          "metadata": {
            "candidateCount": 20,
            "returnedCount": 1,
            "usedGemini": true,
            "phase": "gemini_reranking",
            "modelName": "gemini-2.5-flash-lite"
          }
        }
        """

        let response = try JSONDecoder().decode(RecommendationResponse.self, from: Data(json.utf8))
        let candidate = try #require(response.recommendations.first)

        #expect(candidate.contentItem.title == "Rice Workshop")
        #expect(candidate.contentItem.category == .food)
        #expect(candidate.contentItem.district == "Burnaby")
        #expect(candidate.contentItem.priceLevel == 2)
        #expect(candidate.contentItem.activityTags == ["dinner"])
        #expect(candidate.rank == 1)
        #expect(candidate.reason == "Matches your preference for cozy Korean-friendly cafes in Burnaby.")
        #expect(candidate.finalScore == 0.94)
        #expect(candidate.confidence == 0.87)
        #expect(candidate.deterministicScore == 0.82)
        #expect(candidate.scoreBreakdown.contentQuality == 0.86)
        #expect(candidate.scoreBreakdown.geminiRank == 1)
        #expect(response.metadata?.usedGemini == true)
        #expect(response.metadata?.phase == "gemini_reranking")
    }

    @Test func sourceTypeDecodesBackendSourceValuesAndUnknowns() throws {
        let decoder = JSONDecoder()
        let cases: [(String, SourceType)] = [
            ("curated", .curated),
            ("manual", .manual),
            ("google_places", .googlePlaces),
            ("fsq", .fsq),
            ("meetup", .meetup),
            ("eventbrite", .eventbrite),
            ("luma", .luma),
            ("city_open_data", .cityOpenData),
            ("future_source", .unknown)
        ]

        for (rawValue, expected) in cases {
            let data = Data("\"\(rawValue)\"".utf8)
            #expect(try decoder.decode(SourceType.self, from: data) == expected)
        }
    }

    @Test func googlePlaceDisplayDataDecodesWithoutReviewText() throws {
        let json = """
        {
          "placeId": "ChIJ123",
          "displayName": "Sample Cafe",
          "formattedAddress": "123 Main St, Vancouver, BC",
          "latitude": 49.25,
          "longitude": -123.1,
          "rating": 4.5,
          "userRatingCount": 120,
          "regularOpeningHours": {
            "openNow": true,
            "weekdayDescriptions": ["Monday: 9:00 AM – 5:00 PM"]
          },
          "currentOpeningHours": null,
          "googleMapsUri": "https://maps.google.com/?cid=123",
          "websiteUri": "https://example.com",
          "nationalPhoneNumber": "(604) 555-0100",
          "businessStatus": "OPERATIONAL",
          "photos": [
            {
              "name": "places/ChIJ123/photos/photo-resource",
              "widthPx": 1200,
              "heightPx": 800,
              "authorAttributions": []
            }
          ]
        }
        """

        let details = try JSONDecoder().decode(GooglePlaceDisplayData.self, from: Data(json.utf8))

        #expect(details.placeId == "ChIJ123")
        #expect(details.displayName == "Sample Cafe")
        #expect(details.rating == 4.5)
        #expect(details.userRatingCount == 120)
        #expect(details.regularOpeningHours?.weekdayDescriptions?.first == "Monday: 9:00 AM – 5:00 PM")
        #expect(details.photos.first?.name == "places/ChIJ123/photos/photo-resource")
    }

    @Test func userPreferencesPayloadUsesBackendSnakeCaseValues() throws {
        let preference = UserPreference(
            selectedCategories: ["food", "events"],
            preferredDistricts: ["Burnaby"],
            budgetLevel: 2,
            vibeTags: ["cozy"],
            infoNeeds: ["dinner"],
            languagePreference: .both,
            updatedAt: Date()
        )

        let payload = UserPreferencesPayload(userId: "user-1", preference: preference)
        let data = try JSONEncoder().encode(payload)
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])

        #expect(object["user_id"] as? String == "user-1")
        #expect(object["preferred_categories"] as? [String] == ["food", "events"])
        #expect(object["preferred_areas"] as? [String] == ["Burnaby"])
        #expect(object["budget_level"] as? String == "medium")
        #expect(object["vibe_tags"] as? [String] == ["cozy"])
        #expect(object["activity_tags"] as? [String] == ["dinner"])
        #expect(object["language_preference"] as? String == "any")
        #expect(object["travel_preference"] as? String == "any")
        #expect(object["negative_tags"] as? [String] == [])
        #expect(object["onboarding_completed"] as? Bool == true)
    }

    @Test func recommendationScenariosUseReviewedSeedData() throws {
        let service = RecommendationService()
        let items = try reviewedItems()

        let foodPreference = UserPreference(
            selectedCategories: ["food"],
            preferredDistricts: ["Coquitlam"],
            budgetLevel: 2,
            vibeTags: ["korean-community", "cozy"],
            infoNeeds: [],
            languagePreference: .both,
            updatedAt: Date()
        )
        #expect(service.rankedItems(for: foodPreference, items: items).first?.item.id == "food_001")

        let eventsPreference = UserPreference(
            selectedCategories: ["events"],
            preferredDistricts: ["Downtown"],
            budgetLevel: 4,
            vibeTags: ["career-focused"],
            infoNeeds: [],
            languagePreference: .both,
            updatedAt: Date()
        )
        #expect(service.rankedItems(for: eventsPreference, items: items).first?.item.id == "event_005")

        let lifestylePreference = UserPreference(
            selectedCategories: ["lifestyle"],
            preferredDistricts: ["North Vancouver"],
            budgetLevel: 0,
            vibeTags: ["outdoor"],
            infoNeeds: [],
            languagePreference: .both,
            updatedAt: Date()
        )
        #expect(service.rankedItems(for: lifestylePreference, items: items).first?.item.id == "lifestyle_009")
    }

    @Test func categoryFilteringAndInactiveExclusionWork() {
        let service = RecommendationService()
        let preference = UserPreference.defaultValue
        let items = [
            makeItem(id: "food", category: .food),
            makeItem(id: "event", category: .events),
            makeItem(id: "lifestyle", category: .lifestyle),
            makeItem(id: "inactive", category: .food, isActive: false)
        ]

        let allRanked = service.rankedItems(for: preference, items: items)
        #expect(Set(allRanked.map(\.item.id)) == ["food", "event", "lifestyle"])

        let foodRanked = service.rankedItems(for: preference, items: items, categoryFilter: .food)
        #expect(foodRanked.map(\.item.id) == ["food"])

        let eventRanked = service.rankedItems(for: preference, items: items, categoryFilter: .events)
        #expect(eventRanked.map(\.item.category) == [.events])
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

    private func reviewedItems() throws -> [ContentItem] {
        let data = try Data(contentsOf: reviewedDataURL())
        return try JSONDecoder().decode([ContentItem].self, from: data)
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
