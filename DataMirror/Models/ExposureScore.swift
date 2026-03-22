import Foundation

struct ExposureScore: Equatable, Sendable {
    let total: Int
    let locationScore: Int
    let identityScore: Int
    let behavioralScore: Int
    let deviceScore: Int
    let summary: String
    let topThreeToRevoke: [(PermissionType, Int)]

    static func == (lhs: ExposureScore, rhs: ExposureScore) -> Bool {
        lhs.total == rhs.total
        && lhs.locationScore == rhs.locationScore
        && lhs.identityScore == rhs.identityScore
        && lhs.behavioralScore == rhs.behavioralScore
        && lhs.deviceScore == rhs.deviceScore
        && lhs.summary == rhs.summary
        && lhs.topThreeToRevoke.map(\.0) == rhs.topThreeToRevoke.map(\.0)
        && lhs.topThreeToRevoke.map(\.1) == rhs.topThreeToRevoke.map(\.1)
    }

    nonisolated static let zero = ExposureScore(
        total: 0,
        locationScore: 0,
        identityScore: 0,
        behavioralScore: 0,
        deviceScore: 0,
        summary: String(localized: "Loading your exposure score…"),
        topThreeToRevoke: []
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
            summary = String(localized: "Your exposure footprint is minimal. You've shared very little sensor data with apps.")
        case 30..<60:
            summary = String(localized: "You have a moderate exposure profile. A few high-impact permissions are active.")
        default:
            summary = String(localized: "Your exposure score is high. Revoking the permissions below would significantly reduce your profile.")
        }

        return ExposureScore(
            total: capped,
            locationScore: min(locationScore, 40),
            identityScore: min(identityScore, 30),
            behavioralScore: min(behavioralScore, 20),
            deviceScore: min(deviceScore, 20),
            summary: summary,
            topThreeToRevoke: topThree
        )
    }
}
