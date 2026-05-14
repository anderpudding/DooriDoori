import Foundation
import Supabase

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
