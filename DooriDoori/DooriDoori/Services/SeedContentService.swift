import Foundation

enum SeedContentError: LocalizedError {
    case missingFile
    case decodeFailed(Error)

    var errorDescription: String? {
        switch self {
        case .missingFile:
            return "Could not find the local DooriDoori MVP content file."
        case .decodeFailed(let error):
            return "Could not decode local content: \(error.localizedDescription)"
        }
    }
}

struct SeedContentService {
    var bundle: Bundle = .main

    func loadContentItems() throws -> [ContentItem] {
        let nestedURL = bundle.url(
            forResource: "dooridoori_mvp_content_items",
            withExtension: "json",
            subdirectory: "dooridoori_reviewed_mock_data"
        )
        let flatURL = bundle.url(forResource: "dooridoori_mvp_content_items", withExtension: "json")

        guard let url = nestedURL ?? flatURL else {
            throw SeedContentError.missingFile
        }

        do {
            let data = try Data(contentsOf: url)
            let items = try JSONDecoder().decode([ContentItem].self, from: data)
            return items.filter(\.isActive)
        } catch {
            throw SeedContentError.decodeFailed(error)
        }
    }
}
