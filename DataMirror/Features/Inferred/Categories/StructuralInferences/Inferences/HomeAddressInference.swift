import Foundation

/// Infers the user's home address from overnight location clusters and photo EXIF data.
enum HomeAddressInference: InferenceComputable {
    static let inferenceType: InferenceType = .homeAddress
    static let requiredPermissions: [PermissionType] = [.locationWhenInUse, .photosReadWrite]

    static func compute(from context: InferenceContext) async -> Inference {
        let now = Date()
        var evidenceItems: [Evidence] = []
        var bestLat: Double?
        var bestLon: Double?
        var confidence: Confidence = .veryLow
        var confidenceReason = String(localized: "Insufficient data to determine home address")

        if let locations = context.locationHistory, !locations.isEmpty {
            let overnightLocations = CoordinateCluster.filter(locations, startHour: 22, endHour: 6)
            let weekendLocations = CoordinateCluster.filter(locations, startHour: 8, endHour: 22, weekendsOnly: true)
            let combined = overnightLocations + weekendLocations
            let clusters = CoordinateCluster.cluster(combined)

            if let topCluster = clusters.first, topCluster.count >= 3 {
                bestLat = topCluster.latitude
                bestLon = topCluster.longitude
                let dayCount = Set(combined.map { Calendar.current.startOfDay(for: $0.timestamp) }).count

                if dayCount >= 7 {
                    confidence = .high
                    confidenceReason = String(localized: "Strong overnight location pattern across \(dayCount) days")
                } else if dayCount >= 3 {
                    confidence = .medium
                    confidenceReason = String(localized: "Moderate overnight location pattern across \(dayCount) days")
                } else {
                    confidence = .low
                    confidenceReason = String(localized: "Limited overnight location data (\(dayCount) days)")
                }

                evidenceItems.append(Evidence(
                    id: UUID(), permissionType: .locationWhenInUse,
                    description: String(localized: "\(topCluster.count) location samples during overnight/weekend hours"),
                    rawValue: String(format: "%.4f°, %.4f°", topCluster.latitude, topCluster.longitude),
                    weight: 0.8
                ))
            }
        }

        if let photos = context.photoAssets {
            let photosWithLocation = photos.compactMap { photo -> PhotoLocation? in
                guard let loc = photo.location else { return nil }
                if let date = photo.creationDate {
                    let hour = Calendar.current.component(.hour, from: date)
                    if hour >= 20 || hour <= 8 { return loc }
                }
                return nil
            }

            if !photosWithLocation.isEmpty {
                let photoLocations = photosWithLocation.map { loc in
                    SendableLocation(latitude: loc.latitude, longitude: loc.longitude, altitude: 0, speed: 0, course: 0, timestamp: Date(), horizontalAccuracy: 100)
                }
                let photoClusters = CoordinateCluster.cluster(photoLocations)

                if let topPhotoCluster = photoClusters.first, topPhotoCluster.count >= 5 {
                    evidenceItems.append(Evidence(
                        id: UUID(), permissionType: .photosReadWrite,
                        description: String(localized: "\(topPhotoCluster.count) photos taken at this location during home hours"),
                        rawValue: String(format: "%.4f°, %.4f°", topPhotoCluster.latitude, topPhotoCluster.longitude),
                        weight: 0.5
                    ))

                    if bestLat == nil {
                        bestLat = topPhotoCluster.latitude
                        bestLon = topPhotoCluster.longitude
                        confidence = .medium
                        confidenceReason = String(localized: "Inferred from photo EXIF location clusters")
                    }
                }
            }
        }

        var displayValue: InferenceValue = .unknown
        if let lat = bestLat, let lon = bestLon {
            if let address = await StructuralInferenceEngine.shared.reverseGeocode(latitude: lat, longitude: lon) {
                displayValue = .text(address)
            } else {
                displayValue = .coordinate(lat, lon)
            }
        } else {
            confidence = .veryLow
            confidenceReason = String(localized: "No location or photo data available")
        }

        return Inference(
            id: UUID(), category: .location, type: .homeAddress,
            label: String(localized: "Home Address (Estimated)"),
            value: displayValue, confidence: confidence, confidenceReason: confidenceReason,
            evidence: evidenceItems,
            methodology: String(localized: "Clusters GPS coordinates recorded between 10 PM and 6 AM, plus weekend daytime, into a 0.001° grid (~111 meters). The cell with the most overnight dwell time is identified as home. Photo EXIF coordinates from evening/morning hours are used to corroborate or substitute."),
            databrokerNote: String(localized: "Home address is the single most valuable data point for identity resolution. Combined with name, it enables credit bureau lookups, voter registration matching, and physical mail targeting."),
            permissionsRequired: [.locationWhenInUse, .photosReadWrite], isRealTime: false, lastUpdated: now
        )
    }
}
