import Foundation
import Combine

final class SavedItemStore: ObservableObject {
    @Published private(set) var savedItemIDs: Set<String>

    private let defaults: UserDefaults
    private let key: String

    init(defaults: UserDefaults = .standard, key: String = "dooridoori.savedItemIDs") {
        self.defaults = defaults
        self.key = key
        self.savedItemIDs = Set(defaults.stringArray(forKey: key) ?? [])
    }

    func isSaved(_ item: ContentItem) -> Bool {
        savedItemIDs.contains(item.id)
    }

    func replace(with ids: Set<String>) {
        savedItemIDs = ids
        persist()
    }

    func setSaved(_ isSaved: Bool, for item: ContentItem) {
        if isSaved {
            savedItemIDs.insert(item.id)
        } else {
            savedItemIDs.remove(item.id)
        }
        persist()
    }

    func toggle(_ item: ContentItem) {
        if savedItemIDs.contains(item.id) {
            savedItemIDs.remove(item.id)
        } else {
            savedItemIDs.insert(item.id)
        }
        persist()
    }

    private func persist() {
        defaults.set(Array(savedItemIDs).sorted(), forKey: key)
    }
}
