import SwiftUI

struct RootView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @StateObject private var preferenceStore = PreferenceStore()

    var body: some View {
        Group {
            if hasCompletedOnboarding && preferenceStore.hasStoredPreference {
                MainTabView()
            } else {
                OnboardingView(initialPreference: preferenceStore.preference) { preference in
                    preferenceStore.save(preference)
                    hasCompletedOnboarding = true
                }
            }
        }
        .tint(DooriStyle.accent)
    }
}
