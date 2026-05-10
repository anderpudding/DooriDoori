import SwiftUI

struct TrendingRow: View {
    let rank: Int
    let item: ContentItem

    var body: some View {
        HStack(spacing: 16) {
            ContentImageView(item: item, height: 106, cornerRadius: 10)
                .frame(width: 149)

            HStack(spacing: 12) {
                Text("#\(rank)")
                Text(item.title)
                    .lineLimit(1)
            }
            .font(.system(size: 15, weight: .regular, design: .monospaced))
            .foregroundStyle(DooriStyle.ink)

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
