import Foundation

enum ContentType: String, Codable, Hashable {
    case place
    case event
    case lifestyle
}

enum SourceType: String, Codable, Hashable {
    case curated
    case manual
    case googlePlaces = "google_places"
    case fsq
    case fsqOS = "fsq_os"
    case meetup
    case eventbrite
    case luma
    case cityOpenData = "city_open_data"
    case cityVan = "city_van"
    case unknown

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        self = SourceType(rawValue: rawValue) ?? .unknown
    }
}

struct ContentSchedule: Codable, Hashable {
    enum ScheduleType: String, Codable, Hashable {
        case recurring
        case oneTime = "one_time"
        case alwaysOpen = "always_open"
    }

    let type: ScheduleType
    let openingHours: String?
    let startDateTime: String?
    let endDateTime: String?

    var displayText: String {
        switch type {
        case .recurring:
            return openingHours ?? "Schedule varies"
        case .oneTime:
            if let startDateTime, let endDateTime {
                return "\(startDateTime) - \(endDateTime)"
            }
            return startDateTime ?? "Event date TBA"
        case .alwaysOpen:
            return "Always open"
        }
    }
}

struct Coordinates: Codable, Hashable {
    let lat: Double
    let lng: Double
}

struct ContentItem: Identifiable, Codable, Hashable {
    let id: String
    let type: ContentType
    let category: ContentCategory
    let subcategories: [String]
    let subcategoryContent: String
    let subcategoryDisplayKr: String?
    let nameEn: String
    let nameKr: String?
    let description: String
    let detailDescription: String?
    let city: String
    let district: String
    let address: String
    let coordinates: Coordinates
    let imageURL: String?
    let priceTier: String
    let priceLevel: Int
    let vibeTags: [String]
    let activityTags: [String]
    let koreanRelevanceTags: [String]
    let schedule: ContentSchedule
    let dimensionScores: [String: Double]
    let sourceType: SourceType
    let popularityScore: Double
    let freshnessScore: Double
    let isActive: Bool
    let isApproved: Bool
    let rating: Double?
    let reviewCount: Int?
    let viewCount: Int
    let saveCount: Int
    let qualityScore: Double
    let koreanCommunityFit: Double
    let createdAt: String?
    let updatedAt: String?

    var title: String { nameEn }
    var latitude: Double { coordinates.lat }
    var longitude: Double { coordinates.lng }
    var area: String { district }
    var shortDescription: String? { description }
    var budgetLevel: String { priceTier }

    var displayName: String {
        if let nameKr, !nameKr.isEmpty {
            return "\(nameEn) · \(nameKr)"
        }
        return nameEn
    }

    enum CodingKeys: String, CodingKey {
        case id
        case type
        case category
        case subcategories
        case subcategoryContent = "subcategory_content"
        case subcategoryDisplayKr = "subcategory_display_kr"
        case nameEn = "name_en"
        case nameKr = "name_kr"
        case title
        case description
        case shortDescription = "short_description"
        case shortDescriptionCamel = "shortDescription"
        case detailDescription = "detail_description"
        case city
        case district
        case area
        case address
        case coordinates
        case lat
        case lng
        case imageURL = "image_url"
        case imageURLCamel = "imageUrl"
        case priceTier = "price_tier"
        case budgetLevel = "budget_level"
        case budgetLevelCamel = "budgetLevel"
        case priceLevel = "price_level"
        case vibeTags = "vibe_tags"
        case vibeTagsCamel = "vibeTags"
        case activityTags = "activity_tags"
        case activityTagsCamel = "activityTags"
        case koreanRelevanceTags = "korean_relevance_tags"
        case schedule
        case dimensionScores = "dimension_scores"
        case dimensionScoresCamel = "dimensionScores"
        case sourceType = "source_type"
        case popularityScore = "popularity_score"
        case freshnessScore = "freshness_score"
        case isActive = "is_active"
        case isApproved = "is_approved"
        case rating
        case averageRating = "average_rating"
        case reviewCount = "review_count"
        case viewCount = "view_count"
        case saveCount = "save_count"
        case qualityScore = "quality_score"
        case koreanCommunityFit = "korean_community_fit"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(
        id: String,
        type: ContentType,
        category: ContentCategory,
        subcategories: [String] = [],
        subcategoryContent: String,
        subcategoryDisplayKr: String?,
        nameEn: String,
        nameKr: String?,
        description: String,
        detailDescription: String? = nil,
        city: String,
        district: String,
        address: String,
        coordinates: Coordinates,
        imageURL: String?,
        priceTier: String,
        priceLevel: Int,
        vibeTags: [String],
        activityTags: [String] = [],
        koreanRelevanceTags: [String],
        schedule: ContentSchedule,
        dimensionScores: [String: Double],
        sourceType: SourceType,
        popularityScore: Double,
        freshnessScore: Double,
        isActive: Bool,
        isApproved: Bool = true,
        rating: Double?,
        reviewCount: Int?,
        viewCount: Int = 0,
        saveCount: Int = 0,
        qualityScore: Double = 0,
        koreanCommunityFit: Double = 0,
        createdAt: String?,
        updatedAt: String?
    ) {
        self.id = id
        self.type = type
        self.category = category
        self.subcategories = subcategories
        self.subcategoryContent = subcategoryContent
        self.subcategoryDisplayKr = subcategoryDisplayKr
        self.nameEn = nameEn
        self.nameKr = nameKr
        self.description = description
        self.detailDescription = detailDescription
        self.city = city
        self.district = district
        self.address = address
        self.coordinates = coordinates
        self.imageURL = imageURL
        self.priceTier = priceTier
        self.priceLevel = priceLevel
        self.vibeTags = vibeTags
        self.activityTags = activityTags
        self.koreanRelevanceTags = koreanRelevanceTags
        self.schedule = schedule
        self.dimensionScores = dimensionScores
        self.sourceType = sourceType
        self.popularityScore = popularityScore
        self.freshnessScore = freshnessScore
        self.isActive = isActive
        self.isApproved = isApproved
        self.rating = rating
        self.reviewCount = reviewCount
        self.viewCount = viewCount
        self.saveCount = saveCount
        self.qualityScore = qualityScore
        self.koreanCommunityFit = koreanCommunityFit
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decodeFlexibleString(forKey: .id)
        type = try container.decode(ContentType.self, forKey: .type)
        category = try container.decode(ContentCategory.self, forKey: .category)
        subcategories = try container.decodeIfPresent([String].self, forKey: .subcategories) ?? []

        let decodedTitle = try container.decodeIfPresent(String.self, forKey: .title)
        nameEn = try container.decodeIfPresent(String.self, forKey: .nameEn) ?? decodedTitle ?? "Untitled"
        nameKr = try container.decodeIfPresent(String.self, forKey: .nameKr)

        let shortDescription = try container.decodeIfPresent(String.self, forKey: .shortDescription)
            ?? container.decodeIfPresent(String.self, forKey: .shortDescriptionCamel)
        description = try container.decodeIfPresent(String.self, forKey: .description) ?? shortDescription ?? ""
        detailDescription = try container.decodeIfPresent(String.self, forKey: .detailDescription)

        let decodedArea = try container.decodeIfPresent(String.self, forKey: .area)
        district = try container.decodeIfPresent(String.self, forKey: .district) ?? decodedArea ?? ""
        city = try container.decodeIfPresent(String.self, forKey: .city) ?? "Vancouver"
        address = try container.decodeIfPresent(String.self, forKey: .address) ?? district

        if let coordinates = try container.decodeIfPresent(Coordinates.self, forKey: .coordinates) {
            self.coordinates = coordinates
        } else {
            self.coordinates = Coordinates(
                lat: try container.decodeIfPresent(Double.self, forKey: .lat) ?? 0,
                lng: try container.decodeIfPresent(Double.self, forKey: .lng) ?? 0
            )
        }

        imageURL = try container.decodeIfPresent(String.self, forKey: .imageURL)
            ?? container.decodeIfPresent(String.self, forKey: .imageURLCamel)
        subcategoryContent = try container.decodeIfPresent(String.self, forKey: .subcategoryContent)
            ?? subcategories.first
            ?? category.rawValue
        subcategoryDisplayKr = try container.decodeIfPresent(String.self, forKey: .subcategoryDisplayKr)

        let decodedBudgetLevel = try container.decodeIfPresent(String.self, forKey: .budgetLevel)
            ?? container.decodeIfPresent(String.self, forKey: .budgetLevelCamel)
        priceTier = try container.decodeIfPresent(String.self, forKey: .priceTier)
            ?? Self.priceTier(from: decodedBudgetLevel)
        priceLevel = try container.decodeIfPresent(Int.self, forKey: .priceLevel)
            ?? Self.priceLevel(from: decodedBudgetLevel)

        vibeTags = try container.decodeIfPresent([String].self, forKey: .vibeTags)
            ?? container.decodeIfPresent([String].self, forKey: .vibeTagsCamel)
            ?? []
        let decodedActivityTags = try container.decodeIfPresent([String].self, forKey: .activityTags)
            ?? container.decodeIfPresent([String].self, forKey: .activityTagsCamel)
            ?? []
        activityTags = decodedActivityTags
        koreanRelevanceTags = try container.decodeIfPresent([String].self, forKey: .koreanRelevanceTags)
            ?? decodedActivityTags.filter { $0.contains("korean") }

        schedule = try container.decodeIfPresent(ContentSchedule.self, forKey: .schedule)
            ?? ContentSchedule(type: .alwaysOpen, openingHours: nil, startDateTime: nil, endDateTime: nil)
        dimensionScores = try container.decodeIfPresent([String: Double].self, forKey: .dimensionScores)
            ?? container.decodeIfPresent([String: Double].self, forKey: .dimensionScoresCamel)
            ?? Dictionary(uniqueKeysWithValues: decodedActivityTags.map { ($0, 1.0) })
        sourceType = try container.decodeIfPresent(SourceType.self, forKey: .sourceType) ?? .curated

        qualityScore = try container.decodeIfPresent(Double.self, forKey: .qualityScore) ?? 0
        koreanCommunityFit = try container.decodeIfPresent(Double.self, forKey: .koreanCommunityFit) ?? 0
        viewCount = try container.decodeIfPresent(Int.self, forKey: .viewCount) ?? 0
        saveCount = try container.decodeIfPresent(Int.self, forKey: .saveCount) ?? 0
        reviewCount = try container.decodeIfPresent(Int.self, forKey: .reviewCount)
        rating = try container.decodeIfPresent(Double.self, forKey: .rating)
            ?? container.decodeIfPresent(Double.self, forKey: .averageRating)

        popularityScore = try container.decodeIfPresent(Double.self, forKey: .popularityScore)
            ?? min(1.0, log1p(Double(saveCount + viewCount)) / 10.0)
        freshnessScore = try container.decodeIfPresent(Double.self, forKey: .freshnessScore)
            ?? 0.5

        isActive = try container.decodeIfPresent(Bool.self, forKey: .isActive) ?? true
        isApproved = try container.decodeIfPresent(Bool.self, forKey: .isApproved) ?? true
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(String.self, forKey: .updatedAt)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(type, forKey: .type)
        try container.encode(category, forKey: .category)
        try container.encode(subcategories, forKey: .subcategories)
        try container.encode(nameEn, forKey: .title)
        try container.encode(district, forKey: .area)
        try container.encode(city, forKey: .city)
        try container.encode(address, forKey: .address)
        try container.encode(priceTier, forKey: .budgetLevel)
        try container.encode(vibeTags, forKey: .vibeTags)
        try container.encode(activityTags, forKey: .activityTags)
        try container.encode(description, forKey: .shortDescription)
        try container.encodeIfPresent(detailDescription, forKey: .detailDescription)
        try container.encodeIfPresent(imageURL, forKey: .imageURL)
        try container.encode(isActive, forKey: .isActive)
        try container.encode(isApproved, forKey: .isApproved)
        try container.encode(viewCount, forKey: .viewCount)
        try container.encode(saveCount, forKey: .saveCount)
        try container.encodeIfPresent(reviewCount, forKey: .reviewCount)
        try container.encode(qualityScore, forKey: .qualityScore)
        try container.encode(koreanCommunityFit, forKey: .koreanCommunityFit)
        try container.encodeIfPresent(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(updatedAt, forKey: .updatedAt)
    }

    private static func priceTier(from budgetLevel: String?) -> String {
        switch budgetLevel {
        case "low": "$"
        case "medium": "$$"
        case "high": "$$$"
        case "any": "Any budget"
        default: "Any budget"
        }
    }

    private static func priceLevel(from budgetLevel: String?) -> Int {
        switch budgetLevel {
        case "low": 1
        case "medium": 2
        case "high": 3
        default: 2
        }
    }
}

private extension KeyedDecodingContainer {
    func decodeFlexibleString(forKey key: Key) throws -> String {
        if let string = try decodeIfPresent(String.self, forKey: key) {
            return string
        }
        if let uuid = try decodeIfPresent(UUID.self, forKey: key) {
            return uuid.uuidString
        }
        throw DecodingError.keyNotFound(
            key,
            DecodingError.Context(codingPath: codingPath, debugDescription: "Missing string id")
        )
    }
}
