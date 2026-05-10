import SwiftUI

struct MainPickCard: View {
    let rankedItem: RankedContentItem
    let isSaved: Bool
    let onToggleSaved: () -> Void
    let onTap: () -> Void

    private var item: ContentItem { rankedItem.item }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: onTap) {
                ZStack(alignment: .topLeading) {
                    ContentImageView(item: item, height: 233, cornerRadius: 10)

                    HStack(spacing: 5) {
                        Image(systemName: "sparkle")
                            .font(.system(size: 12, weight: .bold))
                        Text("AI 픽")
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                    }
                    .foregroundStyle(Color.black)
                    .padding(.horizontal, 11)
                    .frame(height: 25)
                    .background(.white, in: Capsule())
                    .padding(.leading, 18)
                    .padding(.top, 16)
                }
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .firstTextBaseline) {
                    Text(item.category.titleKr)
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundStyle(DooriStyle.accent)

                    Spacer()

                    Button(action: onToggleSaved) {
                        Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                            .font(.system(size: 19, weight: .semibold))
                            .foregroundStyle(DooriStyle.accent)
                            .frame(width: 38, height: 38)
                            .background(.white, in: Circle())
                            .overlay(Circle().stroke(Color.black, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(isSaved ? "Unsave item" : "Save item")
                }

                Text(item.title)
                    .font(.system(size: 25, weight: .black))
                    .foregroundStyle(.black)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                if let nameKr = item.nameKr, !nameKr.isEmpty {
                    Text(nameKr)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(DooriStyle.accent)
                }

                Label(item.address, systemImage: "location")
                    .font(.system(size: 13, weight: .regular, design: .monospaced))
                    .foregroundStyle(Color.black.opacity(0.76))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Label(item.priceTier, systemImage: "dollarsign")
                    .font(.system(size: 13, weight: .regular, design: .monospaced))
                    .foregroundStyle(Color.black.opacity(0.76))

                Button(action: onTap) {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "sparkle")
                            .font(.system(size: 12, weight: .bold))
                            .padding(.top, 2)
                        Text(rankedItem.reason)
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                    .foregroundStyle(DooriStyle.ink)
                    .frame(maxWidth: .infinity, minHeight: 63, alignment: .leading)
                    .padding(.horizontal, 16)
                    .background(.white, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.black, lineWidth: 1)
                    )
                    .padding(.top, 8)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
