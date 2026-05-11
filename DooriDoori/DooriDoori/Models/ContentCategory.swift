import Foundation

enum ContentCategory: String, CaseIterable, Identifiable, Codable, Hashable {
    case food
    case events
    case lifestyle

    var id: String { rawValue }

    var titleKr: String {
        switch self {
        case .food: return "맛집"
        case .events: return "이벤트"
        case .lifestyle: return "라이프스타일"
        }
    }

    var titleEn: String {
        switch self {
        case .food: return "Food"
        case .events: return "Events"
        case .lifestyle: return "Lifestyle"
        }
    }

    var symbolName: String {
        switch self {
        case .food: return "fork.knife"
        case .events: return "calendar"
        case .lifestyle: return "sparkles"
        }
    }
}

/// UI-only filter state for the Personal Page chips. Domain category values stay in `ContentCategory`.
enum ContentCategoryFilter: String, CaseIterable, Identifiable, Hashable {
    case all
    case food
    case events
    case lifestyle

    var id: String { rawValue }

    var category: ContentCategory? {
        switch self {
        case .all: return nil
        case .food: return .food
        case .events: return .events
        case .lifestyle: return .lifestyle
        }
    }

    var titleKr: String {
        switch self {
        case .all: return "전체"
        case .food: return ContentCategory.food.titleKr
        case .events: return ContentCategory.events.titleKr
        case .lifestyle: return ContentCategory.lifestyle.titleKr
        }
    }
}
