import Foundation

enum LanguagePreference: String, Codable, CaseIterable, Hashable {
    case ko
    case en
    case both
}

struct UserPreference: Codable, Equatable, Hashable {
    var selectedCategories: [String]
    var preferredDistricts: [String]
    var budgetLevel: Int
    var vibeTags: [String]
    var infoNeeds: [String]
    var languagePreference: LanguagePreference
    var updatedAt: Date

    static let defaultValue = UserPreference(
        selectedCategories: ContentCategory.allCases.map(\.rawValue),
        preferredDistricts: ["Coquitlam", "Burnaby", "Richmond"],
        budgetLevel: 2,
        vibeTags: ["korean-community", "newcomer-friendly", "cozy"],
        infoNeeds: [],
        languagePreference: .both,
        updatedAt: Date()
    )
}
