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

        #if DEBUG
        print("Upserting user_preferences for Supabase user id:", userId)
        #endif

        do {
            try await client
                .from("user_preferences")
                .upsert(payload, onConflict: "user_id")
                .execute()

            #if DEBUG
            print("user_preferences upsert succeeded for Supabase user id:", userId)
            #endif
        } catch {
            #if DEBUG
            print("user_preferences upsert failed for Supabase user id \(userId):", error)
            #endif

            throw error
        }
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

        let isCompleted = rows.first?.onboardingCompleted == true

        #if DEBUG
        if rows.isEmpty {
            print("No user_preferences row found for Supabase user id:", userId)
        } else {
            print("user_preferences onboarding_completed for Supabase user id \(userId):", isCompleted)
        }
        #endif

        return isCompleted
    }
}

private struct OnboardingStatus: Decodable {
    let onboardingCompleted: Bool

    enum CodingKeys: String, CodingKey {
        case onboardingCompleted = "onboarding_completed"
    }
}
