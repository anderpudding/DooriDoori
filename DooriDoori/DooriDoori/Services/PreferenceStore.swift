import Foundation
import Combine

final class PreferenceStore: ObservableObject {
    @Published private(set) var preference: UserPreference

    private let defaults: UserDefaults
    private let key: String

    init(defaults: UserDefaults = .standard, key: String = "dooridoori.userPreference") {
        self.defaults = defaults
        self.key = key
        self.preference = Self.load(defaults: defaults, key: key) ?? .defaultValue
    }

    var hasStoredPreference: Bool {
        defaults.data(forKey: key) != nil
    }

    func save(_ preference: UserPreference) {
        var updated = preference
        updated.updatedAt = Date()
        self.preference = updated

        if let data = try? JSONEncoder().encode(updated) {
            defaults.set(data, forKey: key)
        }
    }

    private static func load(defaults: UserDefaults, key: String) -> UserPreference? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(UserPreference.self, from: data)
    }
}
