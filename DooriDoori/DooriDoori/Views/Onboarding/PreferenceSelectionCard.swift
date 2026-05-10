import SwiftUI

struct PreferenceSelectionCard: View {
    let preference: UserPreference
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 14) {
            Text(preference.title)
                .font(.system(size: 15, weight: .medium, design: .monospaced))
                .foregroundStyle(DooriStyle.ink)

            Spacer()
        }
        .padding(.horizontal, 42)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 68)
        .background(.white, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(isSelected ? DooriStyle.accent : Color.black.opacity(0.09), lineWidth: 1)
        )
    }
}
