import SwiftUI

struct ForYouView: View {
    @ObservedObject var viewModel: RecommendationViewModel
    let onSelectItem: (ContentItem) -> Void
    let onShowAllPicks: () -> Void
    let onShowNotifications: () -> Void
    @State private var selectedDisplayCategory: ContentCategory = .food

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
        .onAppear {
            viewModel.selectedFilter = .all
            viewModel.load()
        }
    }

    private var loadedContent: some View {
        VStack(alignment: .leading, spacing: 24) {
            personalSectionHeader(title: "오늘의 메인 픽", actionTitle: "전체 보기", action: onShowAllPicks)

            if let mainPick = viewModel.mainPick {
                MainPickCard(
                    rankedItem: mainPick,
                    feedback: viewModel.feedback(for: mainPick.item),
                    onFeedback: { viewModel.setFeedback($0, for: mainPick.item) },
                    onTap: { onSelectItem(mainPick.item) }
                )
            }

            Divider()
                .background(Color.black)
                .padding(.top, 2)

            personalSectionHeader(title: "더 둘러보기")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(ContentCategory.allCases) { category in
                        Button {
                            selectedDisplayCategory = category
                        } label: {
                            CategoryChip(title: category.titleKr, isSelected: selectedDisplayCategory == category)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 1)
            }

            if viewModel.moreForYou.isEmpty {
                emptyState
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 17) {
                        ForEach(viewModel.moreForYou.prefix(8)) { ranked in
                            SmallFeedCard(
                                rankedItem: ranked,
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
            HStack(spacing: 0) {
                Text("VAN")
                    .dooriText(.h1, english: true)
                    .foregroundStyle(DooriStyle.accent)
                Text("ORI")
                    .dooriText(.h1, english: true)
                    .foregroundStyle(DooriStyle.ink)
            }

            Spacer()

            Button(action: onShowNotifications) {
                Image(systemName: "bell")
                    .font(.system(size: 22, weight: .regular))
                    .foregroundStyle(DooriStyle.ink)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Notifications")
        }
    }

    private func personalSectionHeader(
        title: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) -> some View {
        HStack(alignment: .center) {
            Text(title)
                .dooriText(.subheading)
                .foregroundStyle(DooriStyle.ink)

            Spacer()

            if let actionTitle, let action {
                Button(action: action) {
                    HStack(spacing: 4) {
                        Text(actionTitle)
                            .dooriText(.bodySmall)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(DooriStyle.accent)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var loadingState: some View {
        VStack(spacing: 14) {
            ProgressView()
            Text("추천을 불러오는 중이에요")
                .dooriText(.body)
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
                .dooriText(.body)
                .foregroundStyle(DooriStyle.ink)
            Text("취향을 조금 넓혀보면 더 많은 픽을 볼 수 있어요.")
                .dooriText(.captionSmall)
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
            Text("추천을 불러오지 못했어요")
                .dooriText(.body)
                .foregroundStyle(DooriStyle.ink)
            Text(message)
                .dooriText(.captionSmall, english: true)
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

struct AllPicksView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: RecommendationViewModel
    let onSelectItem: (ContentItem) -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(DooriStyle.ink)
                        .frame(width: 24, height: 24)
                        .background(.white, in: Circle())
                        .overlay(Circle().stroke(Color.black.opacity(0.08), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .padding(.top, 13)

                Text("오늘의 전체 픽")
                    .dooriText(.h1)
                    .foregroundStyle(DooriStyle.ink)
                    .padding(.top, 20)

                Text(summaryText)
                    .dooriText(.captionSmall)
                    .foregroundStyle(DooriStyle.longText)
                    .lineSpacing(4)
                    .frame(maxWidth: 284, alignment: .leading)

                VStack(spacing: 18) {
                    ForEach(viewModel.rankedRecommendations.prefix(12)) { ranked in
                        AllPickRow(rankedItem: ranked) {
                            onSelectItem(ranked.item)
                        }
                    }
                }
                .padding(.top, 8)
            }
            .padding(.horizontal, 16)
            .padding(.top, 70)
            .padding(.bottom, 28)
        }
        .background(DooriStyle.canvas)
        .navigationBarBackButtonHidden()
        .onAppear {
            viewModel.selectedFilter = .all
        }
    }

    private var summaryText: String {
        let count = viewModel.rankedRecommendations.count
        if let mainPick = viewModel.mainPick {
            return "\(mainPick.item.title)가 마음에 안드시나요? 다른 추천 장소를 확인해보세요 · \(count)곳"
        }
        return "오늘 준비된 추천 장소를 확인해보세요 · \(count)곳"
    }
}

struct NotificationView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Text("알림")
                    .dooriText(.body)
                    .foregroundStyle(DooriStyle.ink)

                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(DooriStyle.ink)
                            .frame(width: 34, height: 34)
                            .background(.white, in: Circle())
                            .overlay(Circle().stroke(Color.black.opacity(0.08), lineWidth: 1))
                    }
                    .buttonStyle(.plain)

                    Spacer()
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 70)

            Spacer()

            Text("아직 알림이 없어요")
                .dooriText(.subheading)
                .foregroundStyle(DooriStyle.ink)

            Spacer()
        }
        .background(DooriStyle.canvas)
        .navigationBarBackButtonHidden()
        // TODO: Replace the empty placeholder with real notice/announcement data when a notification source exists.
    }
}
