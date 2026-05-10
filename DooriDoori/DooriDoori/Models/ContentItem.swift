import Foundation

enum ContentType: String, Codable, Hashable {
    case place
    case event
    case lifestyle
}

enum SourceType: String, Codable, Hashable {
    case curated
    case manual
    case google
    case meetup
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
    let subcategoryContent: String
    let subcategoryDisplayKr: String?
    let nameEn: String
    let nameKr: String?
    let description: String
    let city: String
    let district: String
    let address: String
    let coordinates: Coordinates
    let imageURL: String?
    let priceTier: String
    let priceLevel: Int
    let vibeTags: [String]
    let koreanRelevanceTags: [String]
    let schedule: ContentSchedule
    let dimensionScores: [String: Double]
    let sourceType: SourceType
    let popularityScore: Double
    let freshnessScore: Double
    let isActive: Bool
    let rating: Double?
    let reviewCount: Int?
    let createdAt: String?
    let updatedAt: String?

    var title: String { nameEn }
    var latitude: Double { coordinates.lat }
    var longitude: Double { coordinates.lng }

    var displayName: String {
        if let nameKr, !nameKr.isEmpty {
            return "\(nameEn) · \(nameKr)"
        }
        return nameEn
    }
}
