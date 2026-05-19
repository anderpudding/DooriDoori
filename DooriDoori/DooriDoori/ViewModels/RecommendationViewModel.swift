import Foundation
import Combine
import Supabase

final class RecommendationViewModel: ObservableObject {
    enum LoadState: Equatable {
        case loading
        case loaded
        case empty
        case failed(String)
    }

    @Published var selectedFilter: ContentCategoryFilter = .all
    @Published private(set) var items: [ContentItem] = []
    @Published private(set) var recommendations: [RecommendedContentItem] = []
    @Published private(set) var rankedRecommendations: [RankedContentItem] = []
    @Published private(set) var loadState: LoadState = .loading
    @Published private(set) var needsOnboarding = false
    @Published private(set) var feedbackByContentID: [String: RecommendationFeedback] = [:]

    let preferenceStore: PreferenceStore
    let savedItemStore: SavedItemStore

    private let seedContentService: SeedContentService
    private let recommendationService: RecommendationService
    private let preferenceService: PreferenceService
    private let saveService: SaveService
    private let interactionService: InteractionService
    private var cancellables: Set<AnyCancellable> = []

    init(
        seedContentService: SeedContentService = SeedContentService(),
        preferenceStore: PreferenceStore = PreferenceStore(),
        savedItemStore: SavedItemStore = SavedItemStore(),
        recommendationService: RecommendationService = RecommendationService(),
        preferenceService: PreferenceService = PreferenceService(),
        saveService: SaveService = SaveService(),
        interactionService: InteractionService = InteractionService()
    ) {
        self.seedContentService = seedContentService
        self.preferenceStore = preferenceStore
        self.savedItemStore = savedItemStore
        self.recommendationService = recommendationService
        self.preferenceService = preferenceService
        self.saveService = saveService
        self.interactionService = interactionService

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
        Task {
            await loadFromSupabase()
        }
    }

    func savePreference(_ preference: UserPreference) {
        Task {
            do {
                try await preferenceService.upsertPreference(preference)
                await MainActor.run {
                    preferenceStore.save(preference)
                    needsOnboarding = false
                    load()
                }
            } catch {
                await MainActor.run {
                    loadState = .failed(error.localizedDescription)
                }
            }
        }
    }

    @MainActor
    func loadCurrentPreferenceForEditing() async throws -> UserPreference {
        if let remotePreference = try await preferenceService.fetchPreference() {
            preferenceStore.save(remotePreference)
            return remotePreference
        }

        return preferenceStore.preference
    }

    @MainActor
    func saveEditedPreference(_ preference: UserPreference) async throws {
        try await preferenceService.upsertPreference(preference)
        preferenceStore.save(preference)
        needsOnboarding = false
        load()
    }

    func isSaved(_ item: ContentItem) -> Bool {
        savedItemStore.isSaved(item)
    }

    func toggleSaved(_ item: ContentItem) {
        let shouldSave = !savedItemStore.isSaved(item)
        savedItemStore.setSaved(shouldSave, for: item)
        Task {
            do {
                if shouldSave {
                    try await saveService.save(contentId: item.id)
                } else {
                    try await saveService.unsave(contentId: item.id)
                }
            } catch {
                await MainActor.run {
                    savedItemStore.setSaved(!shouldSave, for: item)
                    loadState = .failed(error.localizedDescription)
                }
            }
        }
    }

    func reason(for item: ContentItem) -> String {
        recommendationService.reason(item: item, preference: preference)
    }

    func feedback(for item: ContentItem) -> RecommendationFeedback? {
        feedbackByContentID[item.id]
    }

    func setFeedback(_ feedback: RecommendationFeedback, for item: ContentItem) {
        let nextValue: RecommendationFeedback? = feedbackByContentID[item.id] == feedback ? nil : feedback
        feedbackByContentID[item.id] = nextValue

        guard let nextValue else { return }

        Task {
            do {
                try await interactionService.record(contentId: item.id, interactionType: nextValue.interactionType)
            } catch {
                // TODO: Persist recommendation feedback through a dedicated backend API once the MVP contract is finalized.
                #if DEBUG
                print("Failed to persist recommendation feedback:", error)
                #endif
            }
        }
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
        if recommendations.isEmpty {
            rankedRecommendations = recommendationService.rankedItems(
                for: preferenceStore.preference,
                items: items,
                categoryFilter: selectedFilter.category
            )
        } else {
            rankedRecommendations = recommendationService.rankedItems(
                from: recommendations,
                categoryFilter: selectedFilter.category
            )
        }
    }

    @MainActor
    private func loadFromSupabase() async {
        loadState = .loading
        needsOnboarding = false

        do {
            let isOnboarded = try await preferenceService.hasCompletedOnboarding()
            guard isOnboarded else {
                needsOnboarding = true
                items = []
                recommendations = []
                rankedRecommendations = []
                loadState = .empty
                return
            }

            if let remotePreference = try await preferenceService.fetchPreference() {
                preferenceStore.save(remotePreference)
            }

            async let fetchedRecommendations = recommendationService.fetchRecommendations()
            async let savedIDs = saveService.fetchSavedContentIDs()

            recommendations = try await fetchedRecommendations
            items = recommendations.map(\.contentItem)
            savedItemStore.replace(with: try await savedIDs)
            refreshRecommendations()
            loadState = rankedRecommendations.isEmpty ? .empty : .loaded
        } catch {
            if Self.isMissingUserPreferencesError(error) {
                #if DEBUG
                print("recommend-for-user returned missing user_preferences; routing to onboarding:", error)
                #endif

                needsOnboarding = true
                items = []
                recommendations = []
                rankedRecommendations = []
                loadState = .empty
                return
            }

            do {
                items = try seedContentService.loadContentItems()
                recommendations = []
                refreshRecommendations()
                loadState = rankedRecommendations.isEmpty ? .empty : .loaded
            } catch {
                items = []
                recommendations = []
                rankedRecommendations = []
                loadState = .failed(error.localizedDescription)
            }
        }
    }

    private static func isMissingUserPreferencesError(_ error: Error) -> Bool {
        guard case let FunctionsError.httpError(code, data) = error, code == 404 else {
            return false
        }

        let message = String(data: data, encoding: .utf8) ?? ""
        return message.contains("User preferences not found")
    }
}

enum RecommendationFeedback: String, Hashable {
    case like
    case dislike

    var interactionType: String {
        switch self {
        case .like: return "like"
        case .dislike: return "dislike"
        }
    }
}
