import Foundation
import Supabase

struct GooglePlaceService {
    private let injectedClient: SupabaseClient?
    private var client: SupabaseClient { injectedClient ?? SupabaseManager.shared.client }

    init(client: SupabaseClient? = nil) {
        injectedClient = client
    }

    func fetchGooglePlaceDetails(contentItemId: String) async throws -> GooglePlaceDisplayData {
        let payload = GooglePlaceDetailsRequest(contentItemId: contentItemId)
        return try await client.functions.invoke(
            "google-place-details",
            options: FunctionInvokeOptions(method: .post, body: payload)
        )
    }

    func fetchGooglePlacePhotoURL(
        photoName: String,
        maxWidthPx: Int = 1200,
        maxHeightPx: Int = 800
    ) async throws -> URL? {
        let payload = GooglePlacePhotoRequest(
            photoName: photoName,
            maxWidthPx: maxWidthPx,
            maxHeightPx: maxHeightPx
        )
        let response: GooglePlacePhotoResponse = try await client.functions.invoke(
            "google-place-photo",
            options: FunctionInvokeOptions(method: .post, body: payload)
        )

        guard let photoUri = response.photoUri else { return nil }
        return URL(string: photoUri)
    }
}

private struct GooglePlaceDetailsRequest: Encodable {
    let contentItemId: String
}

private struct GooglePlacePhotoRequest: Encodable {
    let photoName: String
    let maxWidthPx: Int
    let maxHeightPx: Int
}
