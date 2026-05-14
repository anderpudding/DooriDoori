import Foundation

enum AppConfig {
    static var supabaseURL: URL {
        guard
            let value = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String
        else {
            fatalError("Missing SUPABASE_URL in Info.plist")
        }

        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)

        guard
            !trimmedValue.isEmpty,
            !trimmedValue.hasPrefix("$("),
            let url = URL(string: trimmedValue),
            let scheme = url.scheme,
            ["http", "https"].contains(scheme),
            url.host != nil
        else {
            fatalError("Invalid SUPABASE_URL in Info.plist")
        }

        return url
    }

    static var supabaseAnonKey: String {
        guard
            let value = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String
        else {
            fatalError("Missing SUPABASE_ANON_KEY in Info.plist")
        }

        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedValue.isEmpty, !trimmedValue.hasPrefix("$(") else {
            fatalError("Invalid SUPABASE_ANON_KEY in Info.plist")
        }

        return trimmedValue
    }
}
