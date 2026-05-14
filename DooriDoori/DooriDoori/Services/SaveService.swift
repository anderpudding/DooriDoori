import Foundation
import Supabase

struct SaveService {
    private let injectedClient: SupabaseClient?
    private let injectedAuthService: AuthService?
    private let interactionService: InteractionService
    private var client: SupabaseClient { injectedClient ?? SupabaseManager.shared.client }
    private var authService: AuthService { injectedAuthService ?? .shared }

    init(
        client: SupabaseClient? = nil,
        authService: AuthService? = nil,
        interactionService: InteractionService = InteractionService()
    ) {
        injectedClient = client
        injectedAuthService = authService
        self.interactionService = interactionService
    }

    func fetchSavedContentIDs() async throws -> Set<String> {
        let userId = try await authService.ensureSession()
        let savedItems: [SavedItem] = try await client
            .from("saved_items")
            .select()
            .eq("user_id", value: userId)
            .execute()
            .value

        return Set(savedItems.map(\.contentId))
    }

    func save(contentId: String) async throws {
        let userId = try await authService.ensureSession()
        let payload = SavedItemPayload(userId: userId, contentId: contentId)

        try await client
            .from("saved_items")
            .upsert(payload, onConflict: "user_id,content_id", ignoreDuplicates: true)
            .execute()

        try await interactionService.record(contentId: contentId, interactionType: "save")
    }

    func unsave(contentId: String) async throws {
        let userId = try await authService.ensureSession()

        try await client
            .from("saved_items")
            .delete()
            .eq("user_id", value: userId)
            .eq("content_id", value: contentId)
            .execute()

        try await interactionService.record(contentId: contentId, interactionType: "unsave")
    }
}
