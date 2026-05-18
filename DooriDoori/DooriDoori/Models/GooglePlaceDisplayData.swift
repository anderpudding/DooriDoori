import Foundation

struct GooglePlaceDisplayData: Decodable, Hashable {
    let placeId: String?
    let displayName: String?
    let formattedAddress: String?
    let latitude: Double?
    let longitude: Double?
    let rating: Double?
    let userRatingCount: Int?
    let regularOpeningHours: GooglePlaceOpeningHours?
    let currentOpeningHours: GooglePlaceOpeningHours?
    let googleMapsUri: String?
    let websiteUri: String?
    let nationalPhoneNumber: String?
    let businessStatus: String?
    let photos: [GooglePlacePhoto]
}

struct GooglePlaceOpeningHours: Decodable, Hashable {
    let openNow: Bool?
    let weekdayDescriptions: [String]?
}

struct GooglePlacePhoto: Decodable, Hashable {
    let name: String
    let widthPx: Int?
    let heightPx: Int?
    let authorAttributions: [GooglePlaceAuthorAttribution]
}

struct GooglePlaceAuthorAttribution: Decodable, Hashable {
    let displayName: String?
    let uri: String?
    let photoUri: String?
}

struct GooglePlacePhotoResponse: Decodable, Hashable {
    let name: String?
    let photoUri: String?
}
