import Foundation
import Combine

final class RecommendationViewModel: ObservableObject {
    enum LoadState: Equatable {
        case loading
        case loaded
        case empty
        case failed(String)
    }

    @Published var selectedFilter: ContentCategoryFilter = .all
    @Published private(set) var items: [ContentItem] = []
    @Published private(set) var rankedRecommendations: [RankedContentItem] = []
    @Published private(set) var loadState: LoadState = .loading

    let preferenceStore: PreferenceStore
    let savedItemStore: SavedItemStore

    private let seedContentService: SeedContentService
    private let recommendationService: RecommendationService
    private var cancellables: Set<AnyCancellable> = []

    init(
        seedContentService: SeedContentService = SeedContentService(),
        preferenceStore: PreferenceStore = PreferenceStore(),
        savedItemStore: SavedItemStore = SavedItemStore(),
        recommendationService: RecommendationService = RecommendationService()
    ) {
        self.seedContentService = seedContentService
        self.preferenceStore = preferenceStore
        self.savedItemStore = savedItemStore
        self.recommendationService = recommendationService

        bindStores()
        load()
    }

    var preference: UserPreference {
        preferenceStore.preference
    }

    var mainPick: RankedContentItem? {
        rankedRecommendations.first
    }

    var moreForYou: [RankedContentItem] {
        guard !rankedRecommendations.isEmpty else { return [] }
        return Array(rankedRecommendations.dropFirst())
    }

    var trending: [ContentItem] {
        Array(items.sorted { $0.popularityScore > $1.popularityScore }.prefix(3))
    }

    var recentlyViewed: [ContentItem] {
        Array(items.prefix(3))
    }

    var savedItems: [ContentItem] {
        items.filter { savedItemStore.savedItemIDs.contains($0.id) }
    }

    func load() {
        loadState = .loading
        do {
            items = try seedContentService.loadContentItems()
            loadState = items.isEmpty ? .empty : .loaded
            refreshRecommendations()
        } catch {
            items = []
            rankedRecommendations = []
            loadState = .failed(error.localizedDescription)
        }
    }

    func savePreference(_ preference: UserPreference) {
        preferenceStore.save(preference)
    }

    func isSaved(_ item: ContentItem) -> Bool {
        savedItemStore.isSaved(item)
    }

    func toggleSaved(_ item: ContentItem) {
        savedItemStore.toggle(item)
        objectWillChange.send()
    }

    func reason(for item: ContentItem) -> String {
        recommendationService.reason(item: item, preference: preference)
    }

    private func bindStores() {
        $selectedFilter
            .sink { [weak self] _ in self?.refreshRecommendations() }
            .store(in: &cancellables)

        preferenceStore.$preference
            .sink { [weak self] _ in self?.refreshRecommendations() }
            .store(in: &cancellables)

        savedItemStore.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    private func refreshRecommendations() {
        rankedRecommendations = recommendationService.rankedItems(
            for: preferenceStore.preference,
            items: items,
            categoryFilter: selectedFilter.category
        )
    }
}
