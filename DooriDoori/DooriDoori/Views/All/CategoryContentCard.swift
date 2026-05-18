import SwiftUI

struct CategoryContentCard: View {
    let item: ContentItem
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                ContentImageView(item: item, height: 130, cornerRadius: 0)
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
                        Image(systemName: "mappin")
                            .font(.system(size: 10))
                        Text(item.district)
                            .dooriText(.captionSmall, english: true)
                            .lineLimit(1)
                    }
                    .foregroundStyle(DooriStyle.muted)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(DooriStyle.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .cardShadow()
        }
        .buttonStyle(.plain)
    }
}
