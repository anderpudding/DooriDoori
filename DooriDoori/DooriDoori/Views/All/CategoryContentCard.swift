import SwiftUI

struct CategoryContentCard: View {
    let item: ContentItem
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                ContentImageView(item: item, height: 147, cornerRadius: 10)
                    .frame(maxWidth: .infinity)

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.category.titleKr)
                        .dooriText(.captionSmall)
                        .foregroundStyle(DooriStyle.secondaryText)

                    Text(item.title)
                        .dooriText(.caption, english: true)
                        .foregroundStyle(DooriStyle.ink)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 3) {
                        LocationVectorIcon(size: 12)
                        Text(item.district)
                            .dooriText(.captionSmall, english: true)
                            .lineLimit(1)
                    }
                    .foregroundStyle(DooriStyle.muted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(12)
            .frame(height: 256, alignment: .top)
            .background(DooriStyle.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.black, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}
