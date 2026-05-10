import SwiftUI

struct TrendingRow: View {
    let rank: Int
    let item: FeedItem

    var body: some View {
        HStack(spacing: 16) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(DooriStyle.softGray)
                .frame(width: 149, height: 106)

            HStack(spacing: 12) {
                Text("#\(rank)")
                Text("Name")
            }
            .font(.system(size: 15, weight: .regular, design: .monospaced))
            .foregroundStyle(DooriStyle.ink)

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
