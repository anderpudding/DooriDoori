import SwiftUI

struct OnboardingView: View {
    @State private var selectedPreferences: Set<UserPreference.ID> = []

    let onStart: () -> Void

    var body: some View {
        ZStack {
            DooriStyle.canvas.ignoresSafeArea()

            VStack(spacing: 0) {
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.black.opacity(0.16))
                        Capsule()
                            .fill(DooriStyle.accent)
                            .frame(width: proxy.size.width * 0.26)
                    }
                }
                .frame(height: 5)
                .padding(.horizontal, 16)
                .padding(.top, 65)

                Button {} label: {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(DooriStyle.ink)
                        .frame(width: 44, height: 44, alignment: .leading)
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 22)

                VStack(alignment: .leading, spacing: 10) {
                    Text("어떤 분위기를 선호하시나요?")
                        .font(.system(size: 25, weight: .medium))
                        .foregroundStyle(DooriStyle.ink)
                    Text("관심 있는 항목을 골라주세요")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(DooriStyle.ink)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 24)

                VStack(spacing: 24) {
                    ForEach(MockFeedData.preferences) { preference in
                        Button {
                            if selectedPreferences.contains(preference.id) {
                                selectedPreferences.remove(preference.id)
                            } else {
                                selectedPreferences.insert(preference.id)
                            }
                        } label: {
                            PreferenceSelectionCard(
                                preference: preference,
                                isSelected: selectedPreferences.contains(preference.id)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 42)

                Spacer(minLength: 24)

                PrimaryButton(title: "다음", action: onStart)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 48)
            }
        }
    }
}
