import SwiftUI

struct FeedDetailView: View {
    @Environment(\.dismiss) private var dismiss

    let item: ContentItem
    let reason: String
    @ObservedObject var savedItemStore: SavedItemStore
    let onToggleSaved: (ContentItem) -> Void

    private let interactionService = InteractionService()

    private var isSaved: Bool {
        savedItemStore.isSaved(item)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                topImage

                VStack(alignment: .leading, spacing: 18) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(item.category.titleKr)
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                            .foregroundStyle(DooriStyle.accent)

                        Spacer()

                        Button {
                            onToggleSaved(item)
                        } label: {
                            Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                                .font(.system(size: 21, weight: .semibold))
                                .foregroundStyle(DooriStyle.accent)
                                .frame(width: 42, height: 42)
                                .background(.white, in: Circle())
                                .overlay(Circle().stroke(Color.black, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text(item.title)
                            .font(.system(size: 32, weight: .black))
                            .foregroundStyle(.black)
                            .lineLimit(2)
                            .minimumScaleFactor(0.75)

                        if let nameKr = item.nameKr, !nameKr.isEmpty {
                            Text(nameKr)
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(DooriStyle.accent)
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        detailLabel("location", item.address)
                        detailLabel("mappin.and.ellipse", "\(item.district), \(item.city)")
                        detailLabel("wallet.pass", item.priceTier)
                        detailLabel("calendar", item.schedule.displayText)
                        detailLabel("tray.full", item.sourceType.rawValue.capitalized)
                        if let rating = item.rating {
                            detailLabel("star.fill", String(format: "%.1f", rating))
                        }
                    }

                    reasonBox

                    Divider().background(Color.black)

                    infoSection(title: item.subcategoryDisplayKr ?? item.subcategoryContent.capitalized) {
                        Text(item.description)
                            .font(.system(size: 15, weight: .regular))
                            .foregroundStyle(Color.black.opacity(0.78))
                            .lineSpacing(5)
                    }

                    if let detailDescription = item.detailDescription, !detailDescription.isEmpty {
                        infoSection(title: "Details") {
                            Text(detailDescription)
                                .font(.system(size: 15, weight: .regular))
                                .foregroundStyle(Color.black.opacity(0.78))
                                .lineSpacing(5)
                        }
                    }

                    infoSection(title: "Vibes") {
                        tagWrap(tags: item.vibeTags)
                    }

                    if !item.activityTags.isEmpty {
                        infoSection(title: "Activities") {
                            tagWrap(tags: item.activityTags)
                        }
                    }

                    if !item.koreanRelevanceTags.isEmpty {
                        infoSection(title: "Korean relevance") {
                            tagWrap(tags: item.koreanRelevanceTags)
                        }
                    }
                }
                .padding(17)
            }
        }
        .background(DooriStyle.canvas)
        .navigationBarBackButtonHidden()
        .ignoresSafeArea(edges: .top)
        .task {
            try? await interactionService.record(contentId: item.id, interactionType: "view")
        }
    }

    private var topImage: some View {
        ZStack(alignment: .topLeading) {
            ContentImageView(item: item, height: 381, cornerRadius: 0)

            IconCircleButton(symbolName: "chevron.left", background: .white.opacity(0.94), size: 46) {
                dismiss()
            }
            .padding(.top, 58)
            .padding(.leading, 18)
        }
    }

    private var reasonBox: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "sparkle")
                .font(.system(size: 13, weight: .bold))
                .padding(.top, 2)
            Text(reason)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .lineSpacing(3)
        }
        .foregroundStyle(DooriStyle.ink)
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Color.black, lineWidth: 1))
    }

    private func detailLabel(_ symbol: String, _ text: String) -> some View {
        Label(text, systemImage: symbol)
            .font(.system(size: 13, weight: .regular, design: .monospaced))
            .foregroundStyle(Color.black.opacity(0.76))
    }

    private func infoSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.black)
            content()
        }
    }

    private func tagWrap(tags: [String]) -> some View {
        FlowLayout(spacing: 8, rowSpacing: 8) {
            ForEach(tags, id: \.self) { tag in
                Text(tag)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(DooriStyle.accent)
                    .padding(.horizontal, 10)
                    .frame(height: 30)
                    .background(.white, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Color.black, lineWidth: 1))
            }
        }
    }
}
