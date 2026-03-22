import Foundation
import Photos

// CLLocation is not Sendable in Swift 6, so we store coordinates as value types.
struct PhotoLocation: Equatable, Identifiable, Sendable {
    let id: String
    let latitude: Double
    let longitude: Double
    let altitude: Double?

    init(latitude: Double, longitude: Double, altitude: Double?) {
        self.id = "\(latitude),\(longitude)"
        self.latitude = latitude
        self.longitude = longitude
        self.altitude = altitude
    }
}

struct PhotoAsset: Equatable, Identifiable, Sendable {
    let id: String
    let creationDate: Date?
    let modificationDate: Date?
    let mediaType: PHAssetMediaType
    let mediaSubtypes: PHAssetMediaSubtype
    let pixelWidth: Int
    let pixelHeight: Int
    let duration: TimeInterval
    let isFavorite: Bool
    let isHidden: Bool
    let location: PhotoLocation?
    let cameraMake: String?
    let cameraModel: String?
    let lensModel: String?
    let fNumber: Double?
    let exposureTime: Double?
    let isoSpeed: Int?
    let focalLength: Double?
    let burstIdentifier: String?
    var representsThumbnail: Data?

    static func == (lhs: PhotoAsset, rhs: PhotoAsset) -> Bool {
        lhs.id == rhs.id
    }
}
