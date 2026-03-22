import Foundation

/// Infers the user's work address from weekday business-hour location clusters.
enum WorkAddressInference: InferenceComputable {
    static let inferenceType: InferenceType = .workAddress
    static let requiredPermissions: [PermissionType] = [.locationWhenInUse]

    static func compute(from context: InferenceContext) async -> Inference {
        let now = Date()

        guard let locations = context.locationHistory, !locations.isEmpty else {
            return makeUnknown(reason: String(localized: "Location permission not granted or no history available"), now: now)
        }

        let businessLocations = CoordinateCluster.filter(locations, startHour: 8, endHour: 18, weekdaysOnly: true)
        guard !businessLocations.isEmpty else {
            return makeUnknown(reason: String(localized: "No weekday business-hour location data"), now: now)
        }

        let clusters = CoordinateCluster.cluster(businessLocations)
        let overnightLocations = CoordinateCluster.filter(locations, startHour: 22, endHour: 6)
        let homeCluster = CoordinateCluster.cluster(overnightLocations).first

        let workCluster = clusters.first { cluster in
            guard let home = homeCluster else { return true }
            return abs(cluster.latitude - home.latitude) > 0.002 || abs(cluster.longitude - home.longitude) > 0.002
        }

        guard let work = workCluster, work.count >= 3 else {
            return makeUnknown(reason: String(localized: "No consistent weekday location cluster found distinct from home"), now: now)
        }

        let dayCount = Set(businessLocations.filter {
            abs($0.latitude - work.latitude) < 0.002 && abs($0.longitude - work.longitude) < 0.002
        }.map { Calendar.current.startOfDay(for: $0.timestamp) }).count

        let confidence: Confidence = dayCount >= 5 ? .high : dayCount >= 2 ? .medium : .low
        let evidence = [Evidence(
            id: UUID(), permissionType: .locationWhenInUse,
            description: String(localized: "\(work.count) location samples during weekday business hours"),
            rawValue: String(format: "%.4f°, %.4f°", work.latitude, work.longitude), weight: 0.9
        )]

        var displayValue: InferenceValue = .coordinate(work.latitude, work.longitude)
        if let address = await StructuralInferenceEngine.shared.reverseGeocode(latitude: work.latitude, longitude: work.longitude) {
            displayValue = .text(address)
        }

        return Inference(
            id: UUID(), category: .location, type: .workAddress,
            label: String(localized: "Work Address (Estimated)"),
            value: displayValue, confidence: confidence,
            confidenceReason: String(localized: "Weekday presence detected across \(dayCount) days"),
            evidence: evidence,
            methodology: String(localized: "Clusters GPS coordinates from weekday 8 AM – 6 PM into grid cells. The most-visited cluster that is not the home location is identified as the likely workplace."),
            databrokerNote: String(localized: "Employer inference enables B2B ad targeting, income estimation via company size lookup, and career-transition targeting."),
            permissionsRequired: [.locationWhenInUse], isRealTime: false, lastUpdated: now
        )
    }

    private static func makeUnknown(reason: String, now: Date) -> Inference {
        Inference(
            id: UUID(), category: .location, type: .workAddress,
            label: String(localized: "Work Address (Estimated)"),
            value: .unknown, confidence: .veryLow, confidenceReason: reason, evidence: [],
            methodology: String(localized: "Clusters GPS coordinates from weekday 8 AM – 6 PM into grid cells."),
            databrokerNote: String(localized: "Employer inference enables B2B ad targeting, income estimation via company size lookup, and career-transition targeting."),
            permissionsRequired: [.locationWhenInUse], isRealTime: false, lastUpdated: now
        )
    }
}
