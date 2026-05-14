import Foundation

struct UserPreferencesPayload: Codable, Equatable {
    let userId: String
    let preferredCategories: [String]
    let preferredAreas: [String]
    let budgetLevel: String
    let vibeTags: [String]
    let activityTags: [String]
    let languagePreference: String
    let travelPreference: String
    let negativeTags: [String]
    let onboardingCompleted: Bool

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case preferredCategories = "preferred_categories"
        case preferredAreas = "preferred_areas"
        case budgetLevel = "budget_level"
        case vibeTags = "vibe_tags"
        case activityTags = "activity_tags"
        case languagePreference = "language_preference"
        case travelPreference = "travel_preference"
        case negativeTags = "negative_tags"
        case onboardingCompleted = "onboarding_completed"
    }

    init(userId: String, preference: UserPreference, onboardingCompleted: Bool = true) {
        self.userId = userId
        preferredCategories = preference.selectedCategories
        preferredAreas = preference.preferredDistricts
        budgetLevel = Self.backendBudgetLevel(from: preference.budgetLevel)
        vibeTags = preference.vibeTags
        activityTags = preference.infoNeeds
        languagePreference = Self.backendLanguagePreference(from: preference.languagePreference)
        travelPreference = "any"
        negativeTags = []
        self.onboardingCompleted = onboardingCompleted
    }

    private static func backendBudgetLevel(from level: Int) -> String {
        switch level {
        case ...1: "low"
        case 2: "medium"
        case 3...: "high"
        default: "any"
        }
    }

    private static func backendLanguagePreference(from preference: LanguagePreference) -> String {
        switch preference {
        case .ko: "korean_friendly"
        case .en: "english_okay"
        case .both: "any"
        }
    }
}

struct ScoreBreakdown: Codable, Hashable {
    let categoryMatch: Double
    let vibeMatch: Double
    let locationMatch: Double
    let budgetMatch: Double
    let contentQuality: Double
    let engagementScore: Double
    let freshnessOrDiversity: Double
}

struct RecommendedContentItem: Identifiable, Codable, Hashable {
    let contentItem: ContentItem
    let deterministicScore: Double
    let scoreBreakdown: ScoreBreakdown

    var id: String { contentItem.id }

    enum CodingKeys: String, CodingKey {
        case deterministicScore = "deterministic_score"
        case scoreBreakdown = "score_breakdown"
    }

    init(contentItem: ContentItem, deterministicScore: Double, scoreBreakdown: ScoreBreakdown) {
        self.contentItem = contentItem
        self.deterministicScore = deterministicScore
        self.scoreBreakdown = scoreBreakdown
    }

    init(from decoder: Decoder) throws {
        contentItem = try ContentItem(from: decoder)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        deterministicScore = try container.decode(Double.self, forKey: .deterministicScore)
        scoreBreakdown = try container.decode(ScoreBreakdown.self, forKey: .scoreBreakdown)
    }

    func encode(to encoder: Encoder) throws {
        try contentItem.encode(to: encoder)
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(deterministicScore, forKey: .deterministicScore)
        try container.encode(scoreBreakdown, forKey: .scoreBreakdown)
    }
}

struct RecommendationResponse: Codable {
    let candidates: [RecommendedContentItem]
}

struct SavedItem: Codable, Identifiable, Hashable {
    let id: String?
    let userId: String
    let contentId: String
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case contentId = "content_id"
        case createdAt = "created_at"
    }
}

struct Review: Codable, Identifiable, Hashable {
    let id: String
    let userId: String
    let contentId: String
    let rating: Int
    let comment: String?
    let createdAt: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case contentId = "content_id"
        case rating
        case comment
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct UserInteraction: Codable, Identifiable, Hashable {
    let id: String?
    let userId: String
    let contentId: String
    let interactionType: String
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case contentId = "content_id"
        case interactionType = "interaction_type"
        case createdAt = "created_at"
    }
}

struct UserInteractionPayload: Encodable {
    let userId: String
    let contentId: String
    let interactionType: String
    let metadata: [String: String]

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case contentId = "content_id"
        case interactionType = "interaction_type"
        case metadata
    }
}

struct SavedItemPayload: Encodable {
    let userId: String
    let contentId: String

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case contentId = "content_id"
    }
}
