import SwiftUI

struct AllView: View {
    @ObservedObject var viewModel: RecommendationViewModel
    let onSelectItem: (ContentItem) -> Void

    @State private var selectedRegion = "Vancouver"
    @State private var selectedCategoryFilter: ContentCategoryFilter = .all
    @State private var visibleCount = 8

    private var availableRegions: [String] {
        let cities = viewModel.items.map(\.city).filter { !$0.isEmpty }
        let districts = viewModel.items.map(\.district).filter { !$0.isEmpty }
        return Array(Set(cities + districts)).sorted { lhs, rhs in
            if lhs == "Vancouver" { return true }
            if rhs == "Vancouver" { return false }
            return lhs < rhs
        }
    }

    private var popularPlaces: [ContentItem] {
        let regionPool = viewModel.items.filter {
            $0.city == selectedRegion || $0.district == selectedRegion
        }
        let pool = regionPool.isEmpty ? viewModel.items : regionPool
        let sortedMeaningful = pool
            .filter { $0.viewCount > 0 }
            .sorted { lhs, rhs in
                if lhs.viewCount == rhs.viewCount {
                    return originalIndex(lhs) < originalIndex(rhs)
                }
                return lhs.viewCount > rhs.viewCount
            }
        let fillItems = pool.filter { candidate in
            !sortedMeaningful.contains(where: { $0.id == candidate.id })
        }
        return Array((sortedMeaningful + fillItems).prefix(9))
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
        .onAppear {
            if !availableRegions.contains(selectedRegion), let firstRegion = availableRegions.first {
                selectedRegion = firstRegion
            }
        }
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
                LocationVectorIcon(size: 16)
                    .foregroundStyle(DooriStyle.accent)
                Text(selectedRegion)
                    .dooriText(.body)
                    .foregroundStyle(DooriStyle.ink)
                Image(systemName: "chevron.down")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(DooriStyle.ink)
            }
        }
        .buttonStyle(.plain)
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

    private func originalIndex(_ item: ContentItem) -> Int {
        viewModel.items.firstIndex(where: { $0.id == item.id }) ?? Int.max
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
