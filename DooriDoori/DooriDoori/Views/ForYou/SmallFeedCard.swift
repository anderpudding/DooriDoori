import SwiftUI

struct SmallFeedCard: View {
    let item: FeedItem
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(DooriStyle.softGray)
                    .frame(width: 92, height: 92)
                    .overlay {
                        Image(systemName: item.category.symbolName)
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundStyle(DooriStyle.accent)
                    }

                VStack(alignment: .leading, spacing: 7) {
                    Text(item.category.title)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(DooriStyle.accent)

                    Text(item.name)
                        .font(.system(size: 19, weight: .heavy))
                        .foregroundStyle(DooriStyle.ink)
                        .lineLimit(1)

                    Text(item.address)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(DooriStyle.muted)
                        .lineLimit(2)

                    HStack(spacing: 8) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(DooriStyle.accent)
                        Text(String(format: "%.1f", item.rating))
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(DooriStyle.ink)
                        Text(item.budgetLabel)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(DooriStyle.muted)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(12)
            .background(.white, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(DooriStyle.line, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
