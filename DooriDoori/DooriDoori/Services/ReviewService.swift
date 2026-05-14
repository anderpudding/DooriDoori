import Foundation
import Supabase

struct ReviewService {
    private let injectedClient: SupabaseClient?
    private var client: SupabaseClient { injectedClient ?? SupabaseManager.shared.client }

    init(client: SupabaseClient? = nil) {
        injectedClient = client
    }

    func fetchReviews(contentId: String) async throws -> [Review] {
        try await client
            .from("reviews")
            .select()
            .eq("content_id", value: contentId)
            .order("created_at", ascending: false)
            .execute()
            .value
    }
}
