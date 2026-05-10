import SwiftUI

struct CategoryChip: View {
    let title: String
    let isSelected: Bool

    var body: some View {
        Text(title)
            .font(.system(size: 13, weight: .medium, design: .monospaced))
            .foregroundStyle(isSelected ? .white : DooriStyle.accentSoft)
            .padding(.horizontal, 18)
            .frame(height: 38)
            .background(isSelected ? DooriStyle.accent : .white, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.black, lineWidth: 1)
            )
    }
}
