import Foundation

struct ScoreSnapshot: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let date: Date
    let total: Int
    let locationScore: Int
    let identityScore: Int
    let behavioralScore: Int
    let deviceScore: Int

    nonisolated init(
        id: UUID = UUID(),
        date: Date = Date(),
        total: Int,
        locationScore: Int,
        identityScore: Int,
        behavioralScore: Int,
        deviceScore: Int
    ) {
        self.id = id
        self.date = date
        self.total = total
        self.locationScore = locationScore
        self.identityScore = identityScore
        self.behavioralScore = behavioralScore
        self.deviceScore = deviceScore
    }

    nonisolated init(from score: ExposureScore) {
        self.init(
            total: score.total,
            locationScore: score.locationScore,
            identityScore: score.identityScore,
            behavioralScore: score.behavioralScore,
            deviceScore: score.deviceScore
        )
    }
}
