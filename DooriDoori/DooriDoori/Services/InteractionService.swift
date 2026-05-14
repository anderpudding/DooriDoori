import Foundation
import Supabase

struct InteractionService {
    private let injectedClient: SupabaseClient?
    private let injectedAuthService: AuthService?
    private var client: SupabaseClient { injectedClient ?? SupabaseManager.shared.client }
    private var authService: AuthService { injectedAuthService ?? .shared }

    init(
        client: SupabaseClient? = nil,
        authService: AuthService? = nil
    ) {
        injectedClient = client
        injectedAuthService = authService
    }

    func record(contentId: String, interactionType: String) async throws {
        let userId = try await authService.ensureSession()
        let payload = UserInteractionPayload(
            userId: userId,
            contentId: contentId,
            interactionType: interactionType,
            metadata: [:]
        )

        try await client
            .from("user_interactions")
            .insert(payload)
            .execute()
    }
}
