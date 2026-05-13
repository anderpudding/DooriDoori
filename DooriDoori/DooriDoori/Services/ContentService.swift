import Foundation
import Supabase

struct ContentItem: Codable, Identifiable {
    let id: UUID
    let title: String
    let type: String
    let category: String
    let area: String
    let city: String?
    let budgetLevel: String
    let vibeTags: [String]
    let activityTags: [String]
    let shortDescription: String?
    let imageURL: String?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case type
        case category
        case area
        case city
        case budgetLevel = "budget_level"
        case vibeTags = "vibe_tags"
        case activityTags = "activity_tags"
        case shortDescription = "short_description"
        case imageURL = "image_url"
    }
}

final class ContentService {
    private let client = SupabaseManager.shared.client

    func fetchContentItems() async throws -> [ContentItem] {
        try await client
            .from("content_items")
            .select()
            .eq("is_active", value: true)
            .eq("is_approved", value: true)
            .execute()
            .value
    }
}
