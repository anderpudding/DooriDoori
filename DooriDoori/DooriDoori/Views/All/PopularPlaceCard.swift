import SwiftUI

struct PopularPlaceCard: View {
    let rank: Int
    let item: ContentItem
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(item.category.titleKr)
                        .dooriText(.captionSmall)
                        .foregroundStyle(DooriStyle.secondaryText)

                    Text("#\(rank)  \(item.title)")
                        .dooriText(.subheading, english: true)
                        .foregroundStyle(DooriStyle.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)

                    Spacer(minLength: 4)

                    HStack(spacing: 4) {
                        LocationVectorIcon(size: 16)
                        Text(item.district)
                            .dooriText(.bodySmall, english: true)
                            .lineLimit(1)
                    }
                    .foregroundStyle(DooriStyle.muted)

                    HStack(spacing: 4) {
                        Image(systemName: "person.2")
                            .font(.system(size: 11))
                        Text("\(item.viewCount)명이 관심 있음")
                            .dooriText(.bodySmall)
                    }
                    .foregroundStyle(DooriStyle.muted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                ContentImageView(item: item, height: 88, cornerRadius: 10)
                    .frame(width: 114)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(height: 127)
            .background(DooriStyle.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.black, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}
