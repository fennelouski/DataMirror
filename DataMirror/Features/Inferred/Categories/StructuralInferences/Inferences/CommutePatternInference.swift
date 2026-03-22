import Foundation

/// Infers commute pattern from home and work location clusters.
enum CommutePatternInference: InferenceComputable {
    static let inferenceType: InferenceType = .commutePattern
    static let requiredPermissions: [PermissionType] = [.locationWhenInUse]

    static func compute(from context: InferenceContext) async -> Inference {
        let now = Date()
        guard let locations = context.locationHistory, locations.count >= 10 else {
            return makeUnknown(now: now)
        }

        let homeClusters = CoordinateCluster.cluster(CoordinateCluster.filter(locations, startHour: 22, endHour: 6))
        let businessLocations = CoordinateCluster.filter(locations, startHour: 8, endHour: 18, weekdaysOnly: true)
        let allBusinessClusters = CoordinateCluster.cluster(businessLocations)

        guard let home = homeClusters.first else { return makeUnknown(now: now) }

        let workCluster = allBusinessClusters.first {
            abs($0.latitude - home.latitude) > 0.002 || abs($0.longitude - home.longitude) > 0.002
        }

        guard let work = workCluster else {
            return Inference(
                id: UUID(), category: .location, type: .commutePattern,
                label: String(localized: "Commute Pattern (Estimated)"),
                value: .list([String(localized: "Works from home or no distinct work location detected")]),
                confidence: .low, confidenceReason: String(localized: "Business-hour locations overlap with home cluster"),
                evidence: [],
                methodology: String(localized: "Measures distance between home and work clusters."),
                databrokerNote: String(localized: "Commute patterns enable gas station advertising, podcast ads, and transit app targeting."),
                permissionsRequired: [.locationWhenInUse], isRealTime: false, lastUpdated: now
            )
        }

        let distanceMiles = haversineDistance(lat1: home.latitude, lon1: home.longitude, lat2: work.latitude, lon2: work.longitude)

        let commuteLocations = locations.filter { loc in
            let hour = Calendar.current.component(.hour, from: loc.timestamp)
            let weekday = Calendar.current.component(.weekday, from: loc.timestamp)
            let isWeekday = weekday >= 2 && weekday <= 6
            return isWeekday && ((hour >= 7 && hour <= 9) || (hour >= 16 && hour <= 19))
        }

        let avgSpeedMph: Double = {
            let speeds = commuteLocations.map(\.speed).filter { $0 > 0 }
            guard !speeds.isEmpty else { return 0 }
            return (speeds.reduce(0, +) / Double(speeds.count)) * 2.237
        }()

        let transportMode: String
        if distanceMiles < 1 { transportMode = String(localized: "Walks or cycles") }
        else if avgSpeedMph > 15 { transportMode = String(localized: "Likely drives") }
        else if avgSpeedMph > 5 { transportMode = String(localized: "Takes transit or cycles") }
        else { transportMode = String(localized: "Transport mode unclear") }

        let commuteDetails = [
            String(localized: "~\(String(format: "%.1f", distanceMiles)) miles each way"),
            transportMode,
        ]

        let evidence = [Evidence(
            id: UUID(), permissionType: .locationWhenInUse,
            description: String(localized: "Distance between home and work clusters"),
            rawValue: String(format: "%.1f miles", distanceMiles), weight: 0.7
        )]

        return Inference(
            id: UUID(), category: .location, type: .commutePattern,
            label: String(localized: "Commute Pattern (Estimated)"), value: .list(commuteDetails),
            confidence: .high, confidenceReason: String(localized: "Both home and work locations identified"),
            evidence: evidence,
            methodology: String(localized: "Measures the distance between home and work location clusters and estimates transport mode from average travel speed during commute hours."),
            databrokerNote: String(localized: "Commute patterns enable gas station advertising, podcast ads (commuters are the #1 podcast audience), and transit app targeting."),
            permissionsRequired: [.locationWhenInUse], isRealTime: false, lastUpdated: now
        )
    }

    private static func haversineDistance(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
        let r = 3_958.8
        let dLat = (lat2 - lat1) * .pi / 180
        let dLon = (lon2 - lon1) * .pi / 180
        let a = sin(dLat / 2) * sin(dLat / 2) + cos(lat1 * .pi / 180) * cos(lat2 * .pi / 180) * sin(dLon / 2) * sin(dLon / 2)
        return r * 2 * atan2(sqrt(a), sqrt(1 - a))
    }

    private static func makeUnknown(now: Date) -> Inference {
        Inference(
            id: UUID(), category: .location, type: .commutePattern,
            label: String(localized: "Commute Pattern (Estimated)"), value: .unknown,
            confidence: .veryLow, confidenceReason: String(localized: "Insufficient location data"),
            evidence: [],
            methodology: String(localized: "Measures distance between home and work clusters."),
            databrokerNote: String(localized: "Commute patterns enable gas station advertising, podcast ads, and transit app targeting."),
            permissionsRequired: [.locationWhenInUse], isRealTime: false, lastUpdated: now
        )
    }
}
