import SwiftUI

struct ForYouView: View {
    @ObservedObject var viewModel: RecommendationViewModel
    let onSelectItem: (ContentItem) -> Void

    @State private var showsPreferences = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                header

                switch viewModel.loadState {
                case .loading:
                    loadingState
                case .failed(let message):
                    errorState(message)
                case .empty:
                    emptyState
                case .loaded:
                    loadedContent
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 70)
            .padding(.bottom, 28)
        }
        .background(DooriStyle.canvas)
        .navigationBarBackButtonHidden()
        .sheet(isPresented: $showsPreferences) {
            OnboardingView(initialPreference: viewModel.preference) { preference in
                viewModel.savePreference(preference)
                showsPreferences = false
            }
        }
    }

    private var loadedContent: some View {
        VStack(alignment: .leading, spacing: 24) {
            SectionHeader(title: "오늘의 메인 픽", actionTitle: "전체 보기 >") {
                viewModel.selectedFilter = .all
            }

            if let mainPick = viewModel.mainPick {
                MainPickCard(
                    rankedItem: mainPick,
                    isSaved: viewModel.isSaved(mainPick.item),
                    onToggleSaved: { viewModel.toggleSaved(mainPick.item) },
                    onTap: { onSelectItem(mainPick.item) }
                )
            }

            Divider()
                .background(Color.black)
                .padding(.top, 2)

            SectionHeader(title: "더 둘러보기")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(ContentCategoryFilter.allCases) { filter in
                        Button {
                            viewModel.selectedFilter = filter
                        } label: {
                            CategoryChip(title: filter.titleKr, isSelected: viewModel.selectedFilter == filter)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 1)
            }

            if viewModel.rankedRecommendations.isEmpty {
                emptyState
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 17) {
                        ForEach(viewModel.moreForYou.prefix(8)) { ranked in
                            SmallFeedCard(
                                rankedItem: ranked,
                                isSaved: viewModel.isSaved(ranked.item),
                                onToggleSaved: { viewModel.toggleSaved(ranked.item) },
                                onTap: { onSelectItem(ranked.item) }
                            )
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                Text("LOGO")
                    .font(.system(size: 30, weight: .regular, design: .serif))
                    .foregroundStyle(.black)
                Text(subtitle)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(DooriStyle.accentSoft)
                    .lineLimit(1)
            }

            Spacer()

            Button {
                showsPreferences = true
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 22, weight: .regular))
                    .foregroundStyle(.black)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Edit preferences")
        }
    }

    private var subtitle: String {
        let districts = viewModel.preference.preferredDistricts.prefix(2).joined(separator: ", ")
        return districts.isEmpty ? "Today’s picks for you" : "Today’s picks near \(districts)"
    }

    private var loadingState: some View {
        VStack(spacing: 14) {
            ProgressView()
            Text("추천을 불러오는 중이에요")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(DooriStyle.ink)
        }
        .frame(maxWidth: .infinity, minHeight: 360)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(DooriStyle.accent)
            Text("조건에 맞는 추천이 아직 없어요")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(DooriStyle.ink)
            Text("취향을 조금 넓혀보면 더 많은 픽을 볼 수 있어요.")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(DooriStyle.muted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 220)
        .padding(20)
        .background(.white, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Color.black, lineWidth: 1))
    }

    private func errorState(_ message: String) -> some View {
        VStack(spacing: 12) {
            Text("로컬 데이터를 불러오지 못했어요")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(DooriStyle.ink)
            Text(message)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(DooriStyle.muted)
                .multilineTextAlignment(.center)
            PrimaryButton(title: "다시 시도") {
                viewModel.load()
            }
        }
        .padding(20)
        .background(.white, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Color.black, lineWidth: 1))
    }
}
