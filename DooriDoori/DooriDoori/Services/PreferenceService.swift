import Foundation
import Supabase

struct PreferenceService {
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

    func upsertPreference(_ preference: UserPreference) async throws {
        let userId = try await authService.ensureSession()
        let payload = UserPreferencesPayload(userId: userId, preference: preference)

        try await client
            .from("user_preferences")
            .upsert(payload, onConflict: "user_id")
            .execute()
    }

    func hasCompletedOnboarding() async throws -> Bool {
        let userId = try await authService.ensureSession()
        let rows: [OnboardingStatus] = try await client
            .from("user_preferences")
            .select("onboarding_completed")
            .eq("user_id", value: userId)
            .limit(1)
            .execute()
            .value

        return rows.first?.onboardingCompleted == true
    }
}

private struct OnboardingStatus: Decodable {
    let onboardingCompleted: Bool

    enum CodingKeys: String, CodingKey {
        case onboardingCompleted = "onboarding_completed"
    }
}
