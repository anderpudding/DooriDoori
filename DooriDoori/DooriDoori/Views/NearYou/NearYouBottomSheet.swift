import SwiftUI

struct NearYouBottomSheet: View {
    let items: [ContentItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Capsule()
                .fill(DooriStyle.line)
                .frame(width: 48, height: 5)
                .frame(maxWidth: .infinity)
                .padding(.top, 6)

            HStack {
                Text("Near you")
                    .font(.system(size: 30, weight: .heavy))
                    .foregroundStyle(DooriStyle.ink)
                Spacer()
                IconCircleButton(symbolName: "slider.horizontal.3", size: 42) {}
            }

            VStack(spacing: 12) {
                ForEach(items.prefix(3)) { item in
                    HStack(spacing: 12) {
                        ContentImageView(item: item, height: 74, cornerRadius: 10)
                            .frame(width: 74)

                        VStack(alignment: .leading, spacing: 6) {
                            Text(item.title)
                                .font(.system(size: 17, weight: .heavy))
                                .foregroundStyle(DooriStyle.ink)
                                .lineLimit(1)
                            Text(item.address)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(DooriStyle.muted)
                                .lineLimit(1)
                            Text("0.\((items.firstIndex(of: item) ?? 2) + 4) km away")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundStyle(DooriStyle.accent)
                        }
                        Spacer()
                    }
                    .padding(10)
                    .background(.white, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(DooriStyle.line, lineWidth: 1)
                    )
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 18)
        .background(.white, in: UnevenRoundedRectangle(topLeadingRadius: 32, topTrailingRadius: 32))
        .cardShadow()
    }
}
