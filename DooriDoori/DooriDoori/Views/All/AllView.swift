import SwiftUI

struct AllView: View {
    @ObservedObject var viewModel: RecommendationViewModel
    let onNearMe: () -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                header

                SectionHeader(title: "실시간 인기 장소")

                VStack(spacing: 12) {
                    ForEach(Array(viewModel.trending.enumerated()), id: \.element.id) { index, item in
                        TrendingRow(rank: index + 1, item: item)
                    }
                }

                HStack(alignment: .center) {
                    Text("카테고리")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(DooriStyle.ink)
                    Spacer()
                    Text("+")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(DooriStyle.ink)
                }
                .padding(.top, 8)

                VStack(spacing: 16) {
                    CategoryBrowseCard(
                        title: "Restaurants",
                        subtitle: "",
                        symbolName: "fork.knife",
                        buttonTitle: "내 주변",
                        buttonAction: onNearMe
                    )
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(DooriStyle.softGray)
                        .frame(height: 106)
                }
            }
            .padding(.horizontal, 17)
            .padding(.top, 88)
            .padding(.bottom, 24)
        }
        .background(DooriStyle.canvas)
    }

    private var header: some View {
        HStack {
            Button {} label: {
                HStack(spacing: 8) {
                    Text("Burnaby, BC")
                        .font(.system(size: 26, weight: .black))
                        .foregroundStyle(DooriStyle.ink)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(DooriStyle.muted)
                }
            }
            .buttonStyle(.plain)

            Spacer()

            IconCircleButton(symbolName: "magnifyingglass", size: 43) {}
        }
    }
}
