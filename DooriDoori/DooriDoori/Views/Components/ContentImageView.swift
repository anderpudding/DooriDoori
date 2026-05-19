import SwiftUI

struct ContentImageView: View {
    let item: ContentItem
    var height: CGFloat
    var cornerRadius: CGFloat = 10

    var body: some View {
        GeometryReader { proxy in
            imageContent(width: proxy.size.width)
        }
        .frame(height: height)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    @ViewBuilder
    private func imageContent(width: CGFloat) -> some View {
        ZStack {
            if let imageURL = item.imageURL, let url = URL(string: imageURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: width, height: height)
                            .clipped()
                    default:
                        placeholder(width: width)
                    }
                }
            } else {
                placeholder(width: width)
            }
        }
        .frame(width: width, height: height)
        .clipped()
    }

    private func placeholder(width: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(DooriStyle.softGray)

            LinearGradient(
                colors: [DooriStyle.warm, DooriStyle.accentSoft.opacity(0.35)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 10) {
                Image(systemName: item.category.symbolName)
                    .font(.system(size: height > 160 ? 42 : 24, weight: .semibold))
                    .foregroundStyle(.white)
                Text(item.category.titleKr)
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: width, height: height)
        .clipped()
    }
}
