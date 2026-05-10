import SwiftUI

struct PreferenceSelectionCard: View {
    let title: String
    var subtitle: String?
    var symbolName: String?
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 14) {
            if let symbolName {
                Image(systemName: symbolName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(isSelected ? .white : DooriStyle.accent)
                    .frame(width: 28)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(isSelected ? .white : DooriStyle.ink)

                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(isSelected ? .white.opacity(0.82) : DooriStyle.accentSoft)
                }
            }

            Spacer()

            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(isSelected ? .white : DooriStyle.accentSoft)
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 68)
        .background(isSelected ? DooriStyle.accent : DooriStyle.surface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.black, lineWidth: 1)
        )
    }
}
