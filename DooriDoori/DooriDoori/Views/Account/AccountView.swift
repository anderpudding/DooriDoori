import SwiftUI

struct AccountView: View {
    @ObservedObject var viewModel: RecommendationViewModel
    @State private var aiPreferencesEnabled = true

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 28) {
                profile

                SectionHeader(title: "Recently viewed")
                VStack(spacing: 12) {
                    ForEach(viewModel.recentlyViewed) { item in
                        RecentlyViewedCard(item: item)
                    }
                }

                if !viewModel.savedItems.isEmpty {
                    SectionHeader(title: "Saved")
                    VStack(spacing: 12) {
                        ForEach(viewModel.savedItems.prefix(4)) { item in
                            RecentlyViewedCard(item: item)
                        }
                    }
                }

                SectionHeader(title: "AI Preference")
                VStack(spacing: 0) {
                    Toggle(isOn: $aiPreferencesEnabled) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Personalized picks")
                                .font(.system(size: 18, weight: .heavy))
                                .foregroundStyle(DooriStyle.ink)
                            Text("Use your saved taste profile")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(DooriStyle.muted)
                        }
                    }
                    .tint(DooriStyle.accent)
                    .padding(18)

                    Divider().padding(.leading, 18)

                    Button {} label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 5) {
                                Text("Edit preferences")
                                    .font(.system(size: 18, weight: .heavy))
                                    .foregroundStyle(DooriStyle.ink)
                                Text(viewModel.preference.selectedCategories.joined(separator: ", "))
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(DooriStyle.muted)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(DooriStyle.muted)
                        }
                        .padding(18)
                    }
                    .buttonStyle(.plain)
                }
                .background(.white, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(DooriStyle.line, lineWidth: 1)
                )
            }
            .padding(.horizontal, 20)
            .padding(.top, 26)
            .padding(.bottom, 24)
        }
        .background(Color.white)
    }

    private var profile: some View {
        HStack(spacing: 16) {
            Circle()
                .fill(DooriStyle.warm)
                .frame(width: 82, height: 82)
                .overlay {
                    Text("지")
                        .font(.system(size: 30, weight: .heavy))
                        .foregroundStyle(DooriStyle.accent)
                }

            VStack(alignment: .leading, spacing: 7) {
                Text("지은")
                    .font(.system(size: 34, weight: .heavy))
                    .foregroundStyle(DooriStyle.ink)
                Button {} label: {
                    Text("Edit")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .frame(height: 34)
                        .background(DooriStyle.accent, in: Capsule())
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
    }
}
