import SwiftUI

struct ContentImageView: View {
    let item: ContentItem
    var height: CGFloat
    var cornerRadius: CGFloat = 10

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(DooriStyle.softGray)

            LinearGradient(
                colors: [DooriStyle.warm, DooriStyle.accentSoft.opacity(0.35)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 10) {
                Image(systemName: item.category.symbolName)
                    .font(.system(size: height > 160 ? 42 : 24, weight: .semibold))
                    .foregroundStyle(.white)
                Text(item.category.titleKr)
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white)
            }
        }
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}
