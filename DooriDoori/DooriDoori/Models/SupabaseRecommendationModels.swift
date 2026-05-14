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
    let activityMatch: Double?
    let locationMatch: Double
    let budgetMatch: Double
    let contentQuality: Double
    let engagementScore: Double
    let koreanCommunityFit: Double?
    let freshnessOrDiversity: Double
}

struct RecommendedContentItem: Identifiable, Codable, Hashable {
    let contentItem: ContentItem
    let rank: Int
    let reason: String
    let deterministicScore: Double
    let modelName: String?
    let scoreBreakdown: ScoreBreakdown

    var id: String { contentItem.id }

    enum CodingKeys: String, CodingKey {
        case content
        case rank
        case reason
        case deterministicScore
        case deterministicScoreSnake = "deterministic_score"
        case modelName
        case modelNameSnake = "model_name"
        case scoreBreakdown
        case scoreBreakdownSnake = "score_breakdown"
    }

    init(
        contentItem: ContentItem,
        rank: Int,
        reason: String,
        deterministicScore: Double,
        modelName: String? = nil,
        scoreBreakdown: ScoreBreakdown
    ) {
        self.contentItem = contentItem
        self.rank = rank
        self.reason = reason
        self.deterministicScore = deterministicScore
        self.modelName = modelName
        self.scoreBreakdown = scoreBreakdown
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        contentItem = try container.decodeIfPresent(ContentItem.self, forKey: .content)
            ?? ContentItem(from: decoder)
        rank = try container.decodeIfPresent(Int.self, forKey: .rank) ?? 0
        reason = try container.decodeIfPresent(String.self, forKey: .reason) ?? ""
        deterministicScore = try container.decodeIfPresent(Double.self, forKey: .deterministicScore)
            ?? container.decode(Double.self, forKey: .deterministicScoreSnake)
        modelName = try container.decodeIfPresent(String.self, forKey: .modelName)
            ?? container.decodeIfPresent(String.self, forKey: .modelNameSnake)
        scoreBreakdown = try container.decodeIfPresent(ScoreBreakdown.self, forKey: .scoreBreakdown)
            ?? container.decode(ScoreBreakdown.self, forKey: .scoreBreakdownSnake)
    }

    func encode(to encoder: Encoder) throws {
        try contentItem.encode(to: encoder)
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(rank, forKey: .rank)
        try container.encode(reason, forKey: .reason)
        try container.encode(deterministicScore, forKey: .deterministicScore)
        try container.encodeIfPresent(modelName, forKey: .modelName)
        try container.encode(scoreBreakdown, forKey: .scoreBreakdown)
    }
}

struct RecommendationResponse: Decodable {
    let recommendations: [RecommendedContentItem]
    let metadata: RecommendationMetadata?
    let source: String?

    enum CodingKeys: String, CodingKey {
        case recommendations
        case candidates
        case metadata
        case source
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        recommendations = try container.decodeIfPresent([RecommendedContentItem].self, forKey: .recommendations)
            ?? container.decodeIfPresent([RecommendedContentItem].self, forKey: .candidates)
            ?? []
        metadata = try container.decodeIfPresent(RecommendationMetadata.self, forKey: .metadata)
        source = try container.decodeIfPresent(String.self, forKey: .source)
    }
}

struct RecommendationMetadata: Decodable, Hashable {
    let candidateCount: Int
    let returnedCount: Int
    let usedGemini: Bool
    let phase: String?
    let modelName: String
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
