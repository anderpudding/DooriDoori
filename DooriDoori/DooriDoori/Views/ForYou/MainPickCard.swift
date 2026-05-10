import SwiftUI

struct MainPickCard: View {
    let item: FeedItem
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                ZStack(alignment: .topLeading) {
                    Image(item.imageName)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 227)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(
                            LinearGradient(
                                colors: [.clear, .white.opacity(0.66)],
                                startPoint: .center,
                                endPoint: .bottom
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        )

                    HStack(spacing: 5) {
                        Image(systemName: "sparkle")
                            .font(.system(size: 12, weight: .bold))
                        Text("AI 픽")
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                    }
                    .foregroundStyle(DooriStyle.ink)
                    .padding(.horizontal, 10)
                    .frame(height: 25)
                    .background(.white, in: Capsule())
                    .padding(.leading, 18)
                    .padding(.top, 16)

                    HStack(spacing: 10) {
                        IconCircleButton(symbolName: "hand.thumbsup.fill", foreground: DooriStyle.accent, background: .white.opacity(0.94), size: 38) {}
                        IconCircleButton(symbolName: "hand.thumbsdown", foreground: DooriStyle.ink, background: .white.opacity(0.94), size: 38) {}
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                }

                VStack(alignment: .leading, spacing: 7) {
                    Text(item.category.title)
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundStyle(DooriStyle.accentSoft)

                    Text(item.name)
                        .font(.system(size: 25, weight: .heavy))
                        .foregroundStyle(DooriStyle.ink)
                        .tracking(0.5)

                    Label(item.address, systemImage: "location")
                        .font(.system(size: 13, weight: .regular, design: .monospaced))
                        .foregroundStyle(Color.black.opacity(0.54))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    Label(item.budgetLabel, systemImage: "dollarsign")
                        .font(.system(size: 13, weight: .regular, design: .monospaced))
                        .foregroundStyle(Color.black.opacity(0.54))

                    HStack(spacing: 8) {
                        Image(systemName: "sparkle")
                            .font(.system(size: 12, weight: .bold))
                        Text(item.recommendationReason)
                            .font(.system(size: 12, weight: .regular))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .foregroundStyle(DooriStyle.accent)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .padding(.horizontal, 14)
                    .background(.white, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.black.opacity(0.1), lineWidth: 1)
                    )
                    .padding(.top, 8)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
