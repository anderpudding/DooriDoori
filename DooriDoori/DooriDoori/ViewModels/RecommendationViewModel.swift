import Foundation
import Combine

final class RecommendationViewModel: ObservableObject {
    @Published var selectedCategory: FeedCategory? = nil

    let items: [FeedItem]

    init(items: [FeedItem] = MockFeedData.feedItems) {
        self.items = items
    }

    var mainPick: FeedItem {
        items.first(where: { $0.isAIPick }) ?? items[0]
    }

    var moreForYou: [FeedItem] {
        let remaining = items.filter { !$0.isAIPick }
        guard let selectedCategory else { return remaining }
        return remaining.filter { $0.category == selectedCategory }
    }

    var trending: [FeedItem] {
        Array(items.sorted { $0.rating > $1.rating }.prefix(3))
    }

    var recentlyViewed: [FeedItem] {
        Array(items.prefix(3))
    }
}
