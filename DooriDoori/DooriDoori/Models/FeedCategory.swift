import SwiftUI

enum FeedCategory: String, CaseIterable, Identifiable, Codable {
    case food
    case event
    case lifestyle

    var id: String { rawValue }

    var title: String {
        switch self {
        case .food: return "맛집"
        case .event: return "이벤트"
        case .lifestyle: return "라이프스타일"
        }
    }

    var chipTitle: String {
        switch self {
        case .food: return "맛집"
        case .event: return "이벤트"
        case .lifestyle: return "라이프스타일"
        }
    }

    var symbolName: String {
        switch self {
        case .food: return "fork.knife"
        case .event: return "calendar"
        case .lifestyle: return "sparkles"
        }
    }
}
