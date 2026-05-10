import SwiftUI

struct RecentlyViewedCard: View {
    let item: ContentItem

    var body: some View {
        HStack(spacing: 12) {
            ContentImageView(item: item, height: 74, cornerRadius: 10)
                .frame(width: 74)

            VStack(alignment: .leading, spacing: 6) {
                Text(item.title)
                    .font(.system(size: 18, weight: .heavy))
                    .foregroundStyle(DooriStyle.ink)
                    .lineLimit(1)
                Text(item.category.titleKr)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(DooriStyle.accent)
                Text(item.city)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(DooriStyle.muted)
            }

            Spacer()
        }
        .padding(12)
        .background(.white, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(DooriStyle.line, lineWidth: 1)
        )
    }
}
