import SwiftUI

struct RecentlyViewedCard: View {
    let item: FeedItem

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(DooriStyle.softGray)
                .frame(width: 74, height: 74)
                .overlay {
                    Image(systemName: item.category.symbolName)
                        .foregroundStyle(DooriStyle.accent)
                }

            VStack(alignment: .leading, spacing: 6) {
                Text(item.name)
                    .font(.system(size: 18, weight: .heavy))
                    .foregroundStyle(DooriStyle.ink)
                    .lineLimit(1)
                Text(item.category.title)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(DooriStyle.accent)
                Text(item.city)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(DooriStyle.muted)
            }

            Spacer()
        }
        .padding(12)
        .background(.white, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(DooriStyle.line, lineWidth: 1)
        )
    }
}
