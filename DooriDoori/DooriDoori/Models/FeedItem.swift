import Foundation

struct FeedItem: Identifiable, Hashable {
    let id: UUID
    let name: String
    let category: FeedCategory
    let address: String
    let city: String
    let budgetLabel: String
    let imageName: String
    let recommendationReason: String
    let rating: Double
    let tags: [String]
    let websiteURL: URL?
    let isAIPick: Bool

    init(
        id: UUID = UUID(),
        name: String,
        category: FeedCategory,
        address: String,
        city: String,
        budgetLabel: String,
        imageName: String,
        recommendationReason: String,
        rating: Double,
        tags: [String],
        websiteURL: URL?,
        isAIPick: Bool = false
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.address = address
        self.city = city
        self.budgetLabel = budgetLabel
        self.imageName = imageName
        self.recommendationReason = recommendationReason
        self.rating = rating
        self.tags = tags
        self.websiteURL = websiteURL
        self.isAIPick = isAIPick
    }
}
