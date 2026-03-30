import Foundation

struct ExposureScore: Equatable, Sendable {
    let total: Int
    let locationScore: Int
    let identityScore: Int
    let behavioralScore: Int
    let deviceScore: Int
    let summary: String
    let topContributors: [(PermissionType, Int)]

    static func == (lhs: ExposureScore, rhs: ExposureScore) -> Bool {
        lhs.total == rhs.total
        && lhs.locationScore == rhs.locationScore
        && lhs.identityScore == rhs.identityScore
        && lhs.behavioralScore == rhs.behavioralScore
        && lhs.deviceScore == rhs.deviceScore
        && lhs.summary == rhs.summary
        && lhs.topContributors.map(\.0) == rhs.topContributors.map(\.0)
        && lhs.topContributors.map(\.1) == rhs.topContributors.map(\.1)
    }

    nonisolated static let zero = ExposureScore(
        total: 0,
        locationScore: 0,
        identityScore: 0,
        behavioralScore: 0,
        deviceScore: 0,
        summary: String(localized: "Loading your permission overview…"),
        topContributors: []
    )

    nonisolated static let weights: [PermissionType: Int] = [
        .locationAlways: 25,
        .locationWhenInUse: 15,
        .contacts: 15,
        .tracking: 15,
        .motionFitness: 10,
        .healthRead: 10,
        .healthWrite: 10,
        .microphone: 8,
        .camera: 5,
    ]
    nonisolated static let defaultWeight = 2

    static func compute(from permissions: [PermissionItem]) -> ExposureScore {
        var total = 0
        var locationScore = 0
        var identityScore = 0
        var behavioralScore = 0
        var deviceScore = 0
        var contributions: [(PermissionType, Int)] = []

        for item in permissions where item.status == .granted {
            let weight = weights[item.id] ?? defaultWeight
            total += weight
            contributions.append((item.id, weight))

            switch item.id {
            case .locationAlways, .locationWhenInUse, .preciseLocation:
                locationScore += weight
            case .contacts, .tracking, .faceID, .speechRecognition, .siri:
                identityScore += weight
            case .motionFitness, .healthRead, .healthWrite, .calendar, .reminders,
                 .focusStatus, .backgroundAppRefresh:
                behavioralScore += weight
            default:
                deviceScore += weight
            }
        }

        let capped = min(total, 100)
        let sorted = contributions.sorted { $0.1 > $1.1 }
        let topThree = Array(sorted.prefix(3))

        let summary: String
        switch capped {
        case 0..<30:
            summary = String(localized: "Few granted permissions are active right now, so apps have limited access to sensor and personal data from this overview.")
        case 30..<60:
            summary = String(localized: "A moderate set of permissions is active. The breakdown below shows where access is concentrated.")
        default:
            summary = String(localized: "Several high-impact permissions are active. See the list below for which ones contribute the most to this overview.")
        }

        return ExposureScore(
            total: capped,
            locationScore: min(locationScore, 40),
            identityScore: min(identityScore, 30),
            behavioralScore: min(behavioralScore, 20),
            deviceScore: min(deviceScore, 20),
            summary: summary,
            topContributors: topThree
        )
    }
}
