import SwiftUI

struct CategoryChip: View {
    let title: String
    let isSelected: Bool

    var body: some View {
        Text(title)
            .font(.system(size: 14, weight: .bold, design: .monospaced))
            .foregroundStyle(isSelected ? .white : DooriStyle.ink)
            .padding(.horizontal, 22)
            .frame(height: 38)
            .background(isSelected ? DooriStyle.accentSoft : .white, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isSelected ? Color.black.opacity(0.24) : Color.black.opacity(0.07), lineWidth: 1)
            )
    }
}
