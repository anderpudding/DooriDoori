import SwiftUI

struct AllView: View {
    @ObservedObject var viewModel: RecommendationViewModel
    let onSelectItem: (ContentItem) -> Void

    @State private var selectedRegion = "전체"
    @State private var selectedCategoryFilter: ContentCategoryFilter = .all
    @State private var visibleCount = 8

    private var availableRegions: [String] {
        let districts = Array(Set(viewModel.items.map { $0.district })).sorted()
        return ["전체"] + districts
    }

    private var popularPlaces: [ContentItem] {
        let pool = selectedRegion == "전체"
            ? viewModel.items
            : viewModel.items.filter { $0.district == selectedRegion }
        return Array(pool.sorted { $0.viewCount > $1.viewCount }.prefix(9))
    }

    private var filteredCategoryItems: [ContentItem] {
        guard let category = selectedCategoryFilter.category else { return viewModel.items }
        return viewModel.items.filter { $0.category == category }
    }

    private var visibleCategoryItems: [ContentItem] {
        Array(filteredCategoryItems.prefix(visibleCount))
    }

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                popularSection
                    .padding(.top, 24)
                    .padding(.bottom, 28)

                Divider()
                    .padding(.horizontal, -17)

                categorySection
                    .padding(.top, 24)
            }
            .padding(.horizontal, 17)
            .padding(.top, 56)
            .padding(.bottom, 32)
        }
        .background(DooriStyle.canvas)
        .onChange(of: selectedCategoryFilter) {
            visibleCount = 8
        }
    }

    // MARK: - Popular Section

    private var popularSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center) {
                Text("실시간 인기 장소")
                    .dooriText(.subheading)
                    .foregroundStyle(DooriStyle.ink)

                Spacer()

                regionDropdown
            }

            if viewModel.loadState == .loading {
                loadingView
            } else if popularPlaces.isEmpty {
                emptyPopularView
            } else {
                PopularCarousel(places: popularPlaces, onSelectItem: onSelectItem)
            }
        }
    }

    private var regionDropdown: some View {
        Menu {
            ForEach(availableRegions, id: \.self) { region in
                Button {
                    selectedRegion = region
                } label: {
                    Label(
                        region,
                        systemImage: selectedRegion == region ? "checkmark" : ""
                    )
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(DooriStyle.accent)
                Text(selectedRegion)
                    .dooriText(.captionSmall)
                    .foregroundStyle(DooriStyle.ink)
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(DooriStyle.muted)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.black.opacity(0.1), lineWidth: 1)
            )
        }
    }

    // MARK: - Category Section

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("카테고리")
                .dooriText(.subheading)
                .foregroundStyle(DooriStyle.ink)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(ContentCategoryFilter.allCases) { filter in
                        Button {
                            selectedCategoryFilter = filter
                        } label: {
                            CategoryChip(title: filter.titleKr, isSelected: selectedCategoryFilter == filter)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 1)
            }

            if viewModel.loadState == .loading {
                loadingView
            } else if filteredCategoryItems.isEmpty {
                emptyCategoryView
            } else {
                categoryGrid
            }
        }
    }

    private var categoryGrid: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(Array(visibleCategoryItems.enumerated()), id: \.element.id) { index, item in
                CategoryContentCard(item: item, onTap: { onSelectItem(item) })
                    .onAppear {
                        if index == visibleCategoryItems.count - 1 && visibleCount < filteredCategoryItems.count {
                            visibleCount += 8
                        }
                    }
            }
        }
    }

    // MARK: - States

    private var loadingView: some View {
        HStack {
            Spacer()
            ProgressView()
                .padding(.vertical, 32)
            Spacer()
        }
    }

    private var emptyPopularView: some View {
        HStack {
            Spacer()
            VStack(spacing: 8) {
                Image(systemName: "mappin.slash")
                    .font(.system(size: 28))
                    .foregroundStyle(DooriStyle.muted)
                Text("선택한 지역의 장소가 없습니다")
                    .dooriText(.bodySmall)
                    .foregroundStyle(DooriStyle.muted)
            }
            .padding(.vertical, 40)
            Spacer()
        }
    }

    private var emptyCategoryView: some View {
        HStack {
            Spacer()
            VStack(spacing: 8) {
                Image(systemName: "tray")
                    .font(.system(size: 28))
                    .foregroundStyle(DooriStyle.muted)
                Text("표시할 콘텐츠가 없습니다")
                    .dooriText(.bodySmall)
                    .foregroundStyle(DooriStyle.muted)
            }
            .padding(.vertical, 40)
            Spacer()
        }
    }
}
