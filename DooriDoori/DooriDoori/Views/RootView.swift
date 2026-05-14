import SwiftUI

struct RootView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @StateObject private var preferenceStore = PreferenceStore()
    @State private var isCheckingSession = true
    private let preferenceService = PreferenceService()
    private let authService = AuthService.shared

    var body: some View {
        Group {
            if isCheckingSession {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(DooriStyle.canvas)
            } else if hasCompletedOnboarding {
                MainTabView()
            } else {
                OnboardingView(initialPreference: preferenceStore.preference) { preference in
                    Task {
                        do {
                            try await preferenceService.upsertPreference(preference)
                            preferenceStore.save(preference)
                            hasCompletedOnboarding = true
                        } catch {
                            #if DEBUG
                            print("Failed to save onboarding preferences:", error)
                            #endif
                            hasCompletedOnboarding = false
                        }
                    }
                }
            }
        }
        .tint(DooriStyle.accent)
        .task {
            #if DEBUG
            do {
                try await authService.ensureSession()
                await authService.printCurrentSupabaseAccessTokenOnce()
            } catch {
                print("Session setup failed:", error)
            }
            #endif

            do {
                hasCompletedOnboarding = try await preferenceService.hasCompletedOnboarding()
                if hasCompletedOnboarding, let remotePreference = try await preferenceService.fetchPreference() {
                    preferenceStore.save(remotePreference)
                }
            } catch {
                hasCompletedOnboarding = preferenceStore.hasStoredPreference
            }
            isCheckingSession = false
        }
    }
}
