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

    func fetchPreference() async throws -> UserPreference? {
        let userId = try await authService.ensureSession()
        let rows: [UserPreferencesRow] = try await client
            .from("user_preferences")
            .select("*")
            .eq("user_id", value: userId)
            .limit(1)
            .execute()
            .value

        return rows.first?.userPreference
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

private struct UserPreferencesRow: Decodable {
    let preferredCategories: [String]
    let preferredAreas: [String]
    let budgetLevel: String
    let vibeTags: [String]
    let activityTags: [String]
    let languagePreference: String
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case preferredCategories = "preferred_categories"
        case preferredAreas = "preferred_areas"
        case budgetLevel = "budget_level"
        case vibeTags = "vibe_tags"
        case activityTags = "activity_tags"
        case languagePreference = "language_preference"
        case updatedAt = "updated_at"
    }

    var userPreference: UserPreference {
        UserPreference(
            selectedCategories: preferredCategories,
            preferredDistricts: preferredAreas,
            budgetLevel: Self.appBudgetLevel(from: budgetLevel),
            vibeTags: vibeTags,
            infoNeeds: activityTags,
            languagePreference: Self.appLanguagePreference(from: languagePreference),
            updatedAt: Self.date(from: updatedAt) ?? Date()
        )
    }

    private static func appBudgetLevel(from level: String) -> Int {
        switch level {
        case "low": 1
        case "medium": 2
        case "high": 3
        default: 2
        }
    }

    private static func appLanguagePreference(from preference: String) -> LanguagePreference {
        switch preference {
        case "korean_friendly": .ko
        case "english_okay": .en
        default: .both
        }
    }

    private static func date(from value: String?) -> Date? {
        guard let value else { return nil }
        return ISO8601DateFormatter().date(from: value)
    }
}
