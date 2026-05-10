import Foundation

enum MockFeedData {
    static let preferences: [UserPreference] = [
        UserPreference(title: "아늑하고 여유로운", subtitle: "", symbolName: "sofa"),
        UserPreference(title: "활기차고 트렌디한", subtitle: "", symbolName: "sparkles"),
        UserPreference(title: "조용하고 차분한", subtitle: "", symbolName: "leaf"),
        UserPreference(title: "사람들과 어울리기 좋은", subtitle: "", symbolName: "person.2")
    ]

    static let feedItems: [FeedItem] = [
        FeedItem(
            name: "BIRDIES",
            category: .food,
            address: "3850 Lougheed Hwy., Burnaby, BC V5C 6N4",
            city: "Burnaby",
            budgetLabel: "In-budget",
            imageName: "Birdies",
            recommendationReason: "아늑하고 여유로운 분위기를 좋아하시는 취향에 맞춰 골랐어요!",
            rating: 4.7,
            tags: ["cozy", "brunch", "date spot"],
            websiteURL: URL(string: "https://birdiesrestaurants.com"),
            isAIPick: true
        ),
        FeedItem(
            name: "Sooda Korean BBQ",
            category: .food,
            address: "4455 Lougheed Hwy., Burnaby, BC",
            city: "Burnaby",
            budgetLabel: "$$",
            imageName: "sooda-placeholder",
            recommendationReason: "친구들과 편하게 나누기 좋은 메뉴가 많아요.",
            rating: 4.5,
            tags: ["korean", "group", "late night"],
            websiteURL: URL(string: "https://example.com/sooda")
        ),
        FeedItem(
            name: "Burnaby Village Museum",
            category: .lifestyle,
            address: "6501 Deer Lake Ave., Burnaby, BC",
            city: "Burnaby",
            budgetLabel: "Free",
            imageName: "museum-placeholder",
            recommendationReason: "산책과 가벼운 전시를 함께 즐기기 좋아요.",
            rating: 4.6,
            tags: ["walk", "history", "family"],
            websiteURL: URL(string: "https://example.com/museum")
        ),
        FeedItem(
            name: "Deer Lake Park Picnic",
            category: .lifestyle,
            address: "5435 Sperling Ave., Burnaby, BC",
            city: "Burnaby",
            budgetLabel: "Low spend",
            imageName: "deerlake-placeholder",
            recommendationReason: "조용한 호수 뷰와 여유로운 산책 코스가 있어요.",
            rating: 4.8,
            tags: ["nature", "quiet", "picnic"],
            websiteURL: URL(string: "https://example.com/deer-lake")
        ),
        FeedItem(
            name: "K-Town Night Market",
            category: .event,
            address: "Metrotown area, Burnaby, BC",
            city: "Burnaby",
            budgetLabel: "$",
            imageName: "market-placeholder",
            recommendationReason: "가볍게 들러 새로운 간식과 로컬 브랜드를 발견해보세요.",
            rating: 4.3,
            tags: ["food stalls", "weekend", "local"],
            websiteURL: URL(string: "https://example.com/night-market")
        ),
        FeedItem(
            name: "Cafe La Foret",
            category: .food,
            address: "6848 Jubilee Ave., Burnaby, BC",
            city: "Burnaby",
            budgetLabel: "$$",
            imageName: "laforet-placeholder",
            recommendationReason: "넓고 밝은 공간에서 디저트와 커피를 즐기기 좋아요.",
            rating: 4.4,
            tags: ["cafe", "dessert", "study"],
            websiteURL: URL(string: "https://example.com/la-foret")
        )
    ]
}
