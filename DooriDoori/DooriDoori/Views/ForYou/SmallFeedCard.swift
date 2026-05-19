import SwiftUI

struct SmallFeedCard: View {
    let rankedItem: RankedContentItem
    let onTap: () -> Void

    private var item: ContentItem { rankedItem.item }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 7) {
                Text(item.category.titleKr)
                    .dooriText(.captionSmall)
                    .foregroundStyle(DooriStyle.secondaryText)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Text(item.title)
                    .dooriText(.subheading, english: true)
                    .foregroundStyle(DooriStyle.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Text(item.district)
                    .dooriText(.bodySmall, english: true)
                    .foregroundStyle(DooriStyle.muted)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(width: 172, height: 131, alignment: .topLeading)
            .background(DooriStyle.surface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.black, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct AllPickRow: View {
    let rankedItem: RankedContentItem
    let onTap: () -> Void

    private var item: ContentItem { rankedItem.item }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                ContentImageView(item: item, height: 91, cornerRadius: 10)
                    .frame(width: 96)

                VStack(alignment: .leading, spacing: 12) {
                    Text(item.category.titleKr)
                        .dooriText(.captionSmall)
                        .foregroundStyle(DooriStyle.secondaryText)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    Text(item.title)
                        .dooriText(.subheading, english: true)
                        .foregroundStyle(DooriStyle.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)

                    Spacer(minLength: 0)

                    HStack(spacing: 5) {
                        LocationVectorIcon(size: 14)
                        Text(item.district)
                            .dooriText(.bodySmall, english: true)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    .foregroundStyle(DooriStyle.muted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.right")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(DooriStyle.accent)
            }
            .padding(16)
            .frame(height: 122)
            .background(DooriStyle.surface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Color.black, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}
