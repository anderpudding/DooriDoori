import SwiftUI

struct SmallFeedCard: View {
    let rankedItem: RankedContentItem
    let isSaved: Bool
    let onToggleSaved: () -> Void
    let onTap: () -> Void

    private var item: ContentItem { rankedItem.item }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 9) {
                ContentImageView(item: item, height: 92, cornerRadius: 10)

                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(item.category.titleKr)
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundStyle(DooriStyle.accent)

                        Text(item.title)
                            .font(.system(size: 16, weight: .black))
                            .foregroundStyle(.black)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)

                        Text(item.district)
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundStyle(Color.black.opacity(0.62))

                        Text(item.priceTier)
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundStyle(Color.black.opacity(0.62))
                    }

                    Spacer(minLength: 0)

                    Button(action: onToggleSaved) {
                        Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(DooriStyle.accent)
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(10)
            .frame(width: 172, alignment: .topLeading)
            .frame(minHeight: 204, alignment: .topLeading)
            .background(.white, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.black, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
