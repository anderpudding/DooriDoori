import SwiftUI

struct MainPickCard: View {
    let rankedItem: RankedContentItem
    let feedback: RecommendationFeedback?
    let onFeedback: (RecommendationFeedback) -> Void
    let onTap: () -> Void

    private var item: ContentItem { rankedItem.item }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack(alignment: .topLeading) {
                Button(action: onTap) {
                    ContentImageView(item: item, height: 233, cornerRadius: 10)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)

                HStack(spacing: 5) {
                    Image(systemName: "sparkle")
                        .font(.system(size: 12, weight: .bold))
                    Text("AI 픽")
                        .dooriText(.captionSmall)
                }
                .foregroundStyle(.black)
                .padding(.horizontal, 11)
                .frame(height: 25)
                .background(.white, in: Capsule())
                .padding(.leading, 18)
                .padding(.top, 16)

                HStack(spacing: 8) {
                    FeedbackButton(kind: .like, isSelected: feedback == .like) {
                        onFeedback(.like)
                    }
                    FeedbackButton(kind: .dislike, isSelected: feedback == .dislike) {
                        onFeedback(.dislike)
                    }
                }
                .padding(.top, 174)
                .padding(.leading, 264)
            }

            Button(action: onTap) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(item.category.titleKr)
                        .dooriText(.captionSmall)
                        .foregroundStyle(DooriStyle.secondaryText)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    Text(item.title)
                        .dooriText(.h2, english: true)
                        .foregroundStyle(DooriStyle.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)

                    VStack(alignment: .leading, spacing: 5) {
                        HStack(spacing: 5) {
                            LocationVectorIcon(size: 16)
                            Text(item.address)
                                .dooriText(.bodySmall, english: true)
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .minimumScaleFactor(0.7)
                        }
                        Label(item.priceTier, systemImage: "wallet.pass")
                            .dooriText(.bodySmall, english: true)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    .foregroundStyle(DooriStyle.longText)

                    tagRow
                        .padding(.top, 10)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
        }
    }

    private var tagRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(Array(item.vibeTags.prefix(3)), id: \.self) { tag in
                    PersonalTagChip(title: tag)
                }
            }
        }
    }
}

struct FeedbackButton: View {
    let kind: RecommendationFeedback
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: kind == .like ? "hand.thumbsup" : "hand.thumbsdown")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(isSelected ? .white : DooriStyle.accent)
                .frame(width: 38, height: 38)
                .background(isSelected ? DooriStyle.accent : .white, in: Circle())
                .overlay(Circle().stroke(isSelected ? DooriStyle.accent : Color.black.opacity(0.07), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(kind == .like ? "Like recommendation" : "Dislike recommendation")
    }
}

struct PersonalTagChip: View {
    let title: String

    var body: some View {
        HStack(spacing: 4) {
            Star10Icon(size: 20)
            Text(title)
                .dooriText(.bodySmall, english: true)
                .lineLimit(1)
        }
        .foregroundStyle(DooriStyle.secondaryText)
        .padding(.horizontal, 10)
        .frame(height: 34)
        .background(DooriStyle.surface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Color.black.opacity(0.07), lineWidth: 1))
    }
}

struct Star10Icon: View {
    let size: CGFloat

    var body: some View {
        Star10Shape()
            .fill(DooriStyle.secondaryText)
            .frame(width: size, height: size)
    }
}

private struct Star10Shape: Shape {
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outerRadius = min(rect.width, rect.height) / 2
        let innerRadius = outerRadius * 0.44
        var path = Path()

        for index in 0..<10 {
            let radius = index.isMultiple(of: 2) ? outerRadius : innerRadius
            let angle = -CGFloat.pi / 2 + CGFloat(index) * CGFloat.pi / 5
            let point = CGPoint(
                x: center.x + cos(angle) * radius,
                y: center.y + sin(angle) * radius
            )
            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }

        path.closeSubpath()
        return path
    }
}

struct LocationVectorIcon: View {
    let size: CGFloat

    var body: some View {
        LocationVectorShape()
            .stroke(DooriStyle.longText, style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
            .frame(width: size, height: size)
    }
}

private struct LocationVectorShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height
        let centerX = rect.midX
        let topY = rect.minY + height * 0.08
        let circleRadius = width * 0.28
        let circleCenter = CGPoint(x: centerX, y: topY + circleRadius + height * 0.08)

        path.addEllipse(in: CGRect(
            x: circleCenter.x - circleRadius,
            y: circleCenter.y - circleRadius,
            width: circleRadius * 2,
            height: circleRadius * 2
        ))
        path.move(to: CGPoint(x: centerX, y: rect.maxY - height * 0.08))
        path.addCurve(
            to: CGPoint(x: rect.minX + width * 0.18, y: circleCenter.y + circleRadius * 0.2),
            control1: CGPoint(x: centerX - width * 0.1, y: rect.maxY - height * 0.18),
            control2: CGPoint(x: rect.minX + width * 0.18, y: circleCenter.y + circleRadius)
        )
        path.addCurve(
            to: CGPoint(x: rect.maxX - width * 0.18, y: circleCenter.y + circleRadius * 0.2),
            control1: CGPoint(x: rect.minX + width * 0.18, y: topY),
            control2: CGPoint(x: rect.maxX - width * 0.18, y: topY)
        )
        path.addCurve(
            to: CGPoint(x: centerX, y: rect.maxY - height * 0.08),
            control1: CGPoint(x: rect.maxX - width * 0.18, y: circleCenter.y + circleRadius),
            control2: CGPoint(x: centerX + width * 0.1, y: rect.maxY - height * 0.18)
        )
        return path
    }
}
