import SwiftUI

enum MainTab: String, CaseIterable, Identifiable {
    case all = "전체"
    case forYou = "퍼스널"
    case account = "프로필"

    var id: String { rawValue }

    var symbolName: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .forYou: return "sparkles"
        case .account: return "person"
        }
    }
}

enum MainRoute: Hashable {
    case detail(ContentItem)
    case nearYou
    case allPicks
    case notifications
    case writeReview(ContentItem)
}

struct MainTabView: View {
    @StateObject private var appState = AppState()
    @StateObject private var recommendations = RecommendationViewModel()
    @State private var path: [MainRoute] = []

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 0) {
                ZStack {
                    switch appState.selectedTab {
                    case .all:
                        AllView(viewModel: recommendations, onSelectItem: { item in
                            path.append(.detail(item))
                        })
                    case .forYou:
                        ForYouView(
                            viewModel: recommendations,
                            onSelectItem: { item in
                                path.append(.detail(item))
                            },
                            onShowAllPicks: {
                                path.append(.allPicks)
                            },
                            onShowNotifications: {
                                path.append(.notifications)
                            }
                        )
                    case .account:
                        AccountView(viewModel: recommendations)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                CustomTabBar(selectedTab: $appState.selectedTab)
            }
        .background(DooriStyle.canvas)
            .navigationDestination(for: MainRoute.self) { route in
                switch route {
                case .detail(let item):
                    FeedDetailView(
                        item: item,
                        reason: recommendations.reason(for: item),
                        onWriteReview: { selectedItem in
                            path.append(.writeReview(selectedItem))
                        }
                    )
                case .nearYou:
                    NearYouView(items: recommendations.items)
                case .allPicks:
                    AllPicksView(viewModel: recommendations) { item in
                        path.append(.detail(item))
                    }
                case .notifications:
                    NotificationView()
                case .writeReview(let item):
                    ReviewWriteView(item: item)
                }
            }
        }
    }
}
