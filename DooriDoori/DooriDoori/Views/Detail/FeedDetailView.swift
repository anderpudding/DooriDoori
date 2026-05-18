import SwiftUI

struct FeedDetailView: View {
    @Environment(\.dismiss) private var dismiss

    let item: ContentItem
    let reason: String
    let onWriteReview: (ContentItem) -> Void

    @State private var reviews: [Review] = []
    @State private var reviewLoadFailed = false

    private let interactionService = InteractionService()
    private let reviewService = ReviewService()

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                topImage

                VStack(alignment: .leading, spacing: 18) {
                    Text(item.category.titleKr)
                        .dooriText(.captionSmall)
                        .foregroundStyle(DooriStyle.secondaryText)

                    Text(item.title)
                        .dooriText(.h2, english: true)
                        .foregroundStyle(DooriStyle.ink)
                        .lineLimit(2)
                        .minimumScaleFactor(0.75)

                    detailFacts

                    tagWrap(tags: Array(item.vibeTags.prefix(3)))
                        .padding(.top, 4)

                    Divider()
                        .background(Color.black)
                        .padding(.top, 12)

                    infoSection(title: "상세 정보") {
                        Text(item.description)
                            .dooriText(.body)
                            .foregroundStyle(DooriStyle.longText)
                            .lineSpacing(5)
                    }

                    if let detailDescription = item.detailDescription, !detailDescription.isEmpty {
                        Text(detailDescription)
                            .dooriText(.body)
                            .foregroundStyle(DooriStyle.longText)
                            .lineSpacing(5)
                    }

                    Divider()
                        .background(Color.black)
                        .padding(.top, 12)

                    reviewSection
                }
                .padding(.horizontal, 17)
                .padding(.top, 22)
                .padding(.bottom, 28)
            }
        }
        .background(DooriStyle.canvas)
        .navigationBarBackButtonHidden()
        .ignoresSafeArea(edges: .top)
        .task {
            try? await interactionService.record(contentId: item.id, interactionType: "view")
            await loadReviews()
        }
    }

    private var topImage: some View {
        ZStack(alignment: .topLeading) {
            ContentImageView(item: item, height: 381, cornerRadius: 0)

            IconCircleButton(symbolName: "chevron.left", background: .white.opacity(0.94), size: 34) {
                dismiss()
            }
            .padding(.top, 70)
            .padding(.leading, 18)

            Text("...")
                .font(.system(size: 22, weight: .regular))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, 20)
        }
    }

    private var detailFacts: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 5) {
                LocationVectorIcon(size: 16)
                Text(item.address)
                    .dooriText(.bodySmall, english: true)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 4)
                directionsLink
            }

            detailLabel("mappin.and.ellipse", "\(item.district), \(item.city)")
            detailLabel("wallet.pass", item.priceTier)

            if let rating = item.rating {
                detailLabel(
                    "star.fill",
                    "\(String(format: "%.1f", rating)) · 리뷰 \(item.reviewCount ?? reviews.count)"
                )
            }
        }
        .foregroundStyle(DooriStyle.longText)
    }

    private var directionsLink: some View {
        Link(destination: mapsURL) {
            Image(systemName: "arrow.up.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(DooriStyle.accent)
                .frame(width: 20, height: 20)
        }
        .accessibilityLabel("Open directions")
    }

    private var mapsURL: URL {
        let encoded = item.address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return URL(string: "http://maps.apple.com/?q=\(encoded)&ll=\(item.latitude),\(item.longitude)")!
    }

    private var reviewSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("리뷰")
                .dooriText(.subheading)
                .foregroundStyle(DooriStyle.ink)

            HStack(spacing: 9) {
                Circle()
                    .fill(DooriStyle.softGray)
                    .frame(width: 34, height: 34)

                RatingStars(rating: Int(item.rating?.rounded() ?? 0), size: 29, spacing: 6)

                Spacer()

                Button("리뷰 쓰기") {
                    onWriteReview(item)
                }
                .dooriText(.bodySmall)
                .foregroundStyle(DooriStyle.ink)
            }

            if reviewLoadFailed {
                Text("리뷰를 불러오지 못했어요.")
                    .dooriText(.captionSmall)
                    .foregroundStyle(DooriStyle.muted)
            } else if reviews.isEmpty {
                mockReviewList
            } else {
                ForEach(reviews.prefix(2)) { review in
                    ReviewCard(review: review)
                }
            }

            Button {
            } label: {
                HStack(spacing: 5) {
                    Text("리뷰 더보기")
                        .dooriText(.bodySmall)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundStyle(DooriStyle.ink)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(DooriStyle.surface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Color.black, lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
    }

    private var mockReviewList: some View {
        VStack(spacing: 17) {
            ReviewPlaceholderCard(
                rating: 4,
                date: "3일전",
                comment: "분위기도 좋고 직원들도 친절했어요. 전체적으로 만족스러운 식사였고 다시 방문할 의향 있어요."
            )
            ReviewPlaceholderCard(
                rating: 3,
                date: "2026.03.20",
                comment: "Nice atmosphere and friendly staff, but the food was average and a bit over... Service slowed down when it got busy and..."
            )
        }
    }

    private func detailLabel(_ symbol: String, _ text: String) -> some View {
        Label(text, systemImage: symbol)
            .dooriText(.bodySmall, english: true)
    }

    private func infoSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .dooriText(.subheading)
                .foregroundStyle(DooriStyle.ink)
            content()
        }
    }

    private func tagWrap(tags: [String]) -> some View {
        FlowLayout(spacing: 12, rowSpacing: 8) {
            ForEach(tags, id: \.self) { tag in
                PersonalTagChip(title: tag)
            }
        }
    }

    @MainActor
    private func loadReviews() async {
        do {
            reviews = try await reviewService.fetchReviews(contentId: item.id)
            reviewLoadFailed = false
        } catch {
            reviewLoadFailed = true
        }
    }
}

struct ReviewWriteView: View {
    @Environment(\.dismiss) private var dismiss

    let item: ContentItem
    @State private var rating = 0
    @State private var comment = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(DooriStyle.ink)
                    .frame(width: 24, height: 24)
                    .background(.white, in: Circle())
                    .overlay(Circle().stroke(Color.black.opacity(0.08), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .padding(.top, 83)
            .padding(.leading, 18)

            VStack(alignment: .leading, spacing: 9) {
                Text(item.title)
                    .dooriText(.h1, english: true)
                    .foregroundStyle(DooriStyle.ink)

                if let nameKr = item.nameKr, !nameKr.isEmpty {
                    Text(nameKr)
                        .dooriText(.body)
                        .foregroundStyle(DooriStyle.longText)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 23)

            HStack(spacing: 24) {
                Circle()
                    .fill(DooriStyle.softGray)
                    .frame(width: 34, height: 34)

                HStack(spacing: 30) {
                    ForEach(1...5, id: \.self) { value in
                        Button {
                            rating = value
                        } label: {
                            Image(systemName: value <= rating ? "star.fill" : "star")
                                .font(.system(size: 32, weight: .regular))
                                .foregroundStyle(DooriStyle.accent)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 17)
            .padding(.top, 42)

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(DooriStyle.surface)
                    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Color.black, lineWidth: 1))

                if comment.isEmpty {
                    Text("방문하신 경험은 어떠셨나요?")
                        .dooriText(.captionSmall)
                        .foregroundStyle(DooriStyle.muted)
                        .padding(.horizontal, 15)
                        .padding(.vertical, 17)
                }

                TextEditor(text: $comment)
                    .font(.custom("Noto Sans KR", size: DooriTextStyle.body.size).weight(DooriTextStyle.body.weight))
                    .foregroundStyle(DooriStyle.ink)
                    .scrollContentBackground(.hidden)
                    .padding(10)
            }
            .frame(height: 131)
            .padding(.horizontal, 16)
            .padding(.top, 30)

            Spacer()

            Button {
                // TODO: Wire this form to ReviewService once review submission is available.
            } label: {
                Text("게시")
                    .dooriText(.body)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(DooriStyle.accent, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(rating == 0 || comment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .opacity((rating == 0 || comment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) ? 0.45 : 1)
            .padding(.horizontal, 16)
            .padding(.bottom, 48)
        }
        .background(DooriStyle.canvas)
        .navigationBarBackButtonHidden()
    }
}

private struct RatingStars: View {
    let rating: Int
    let size: CGFloat
    let spacing: CGFloat

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(1...5, id: \.self) { index in
                Image(systemName: index <= rating ? "star.fill" : "star")
                    .font(.system(size: size, weight: .regular))
                    .foregroundStyle(DooriStyle.accent)
            }
        }
    }
}

private struct ReviewCard: View {
    let review: Review

    var body: some View {
        ReviewPlaceholderCard(
            rating: review.rating,
            date: review.createdAt ?? "",
            comment: review.comment ?? ""
        )
    }
}

private struct ReviewPlaceholderCard: View {
    let rating: Int
    let date: String
    let comment: String

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 13) {
                Circle()
                    .fill(DooriStyle.softGray)
                    .frame(width: 34, height: 34)

                VStack(alignment: .leading, spacing: 6) {
                    Text("username")
                        .dooriText(.bodySmall, english: true)
                        .foregroundStyle(DooriStyle.ink)

                    HStack(spacing: 4) {
                        RatingStars(rating: rating, size: 14, spacing: 2)
                        Text("\(Double(rating), specifier: "%.1f")")
                        Text("|")
                        Text(date)
                    }
                    .dooriText(.navBar, english: true)
                    .foregroundStyle(DooriStyle.muted)
                }
            }

            Text(comment)
                .dooriText(.body, english: !comment.containsKoreanText)
                .foregroundStyle(DooriStyle.longText)
                .lineSpacing(5)
                .lineLimit(3)

            HStack {
                Spacer()
                Text("더보기")
                    .dooriText(.captionSmall)
                    .foregroundStyle(DooriStyle.ink)
                    .padding(.trailing, 24)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DooriStyle.surface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Color.black, lineWidth: 1))
    }
}
