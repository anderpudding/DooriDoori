import SwiftUI

struct PopularCarousel: View {
    let places: [ContentItem]
    let onSelectItem: (ContentItem) -> Void

    private var pages: [[ContentItem]] {
        stride(from: 0, to: places.count, by: 3).map {
            Array(places[$0..<min($0 + 3, places.count)])
        }
    }

    var body: some View {
        TabView {
            ForEach(0..<pages.count, id: \.self) { pageIndex in
                VStack(spacing: 12) {
                    ForEach(Array(pages[pageIndex].enumerated()), id: \.element.id) { index, item in
                        PopularPlaceCard(
                            rank: pageIndex * 3 + index + 1,
                            item: item,
                            onTap: { onSelectItem(item) }
                        )
                    }
                    Spacer(minLength: 0)
                }
                .padding(.top, 8)
                .padding(.bottom, 48)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .frame(height: 440)
        .onAppear {
            UIPageControl.appearance().currentPageIndicatorTintColor = UIColor(DooriStyle.accent)
            UIPageControl.appearance().pageIndicatorTintColor = UIColor(DooriStyle.softGray)
        }
    }
}
