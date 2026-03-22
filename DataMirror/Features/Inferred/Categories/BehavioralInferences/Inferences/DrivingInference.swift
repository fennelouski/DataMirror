import Foundation
import CoreMotion

/// Infers whether the user is currently driving, with speed estimation.
enum DrivingInference {
    static func compute(activity: CMMotionActivity?, snapshot: BehavioralSensorSnapshot) -> Inference {
        let now = Date()
        var evidenceItems: [Evidence] = []

        let isAutomotive = activity?.automotive ?? false
        let speedMph = snapshot.locationSpeed > 0 ? snapshot.locationSpeed * 2.237 : 0
        let hasCourse = snapshot.locationCourse >= 0

        if isAutomotive { evidenceItems.append(Evidence(id: UUID(), permissionType: .motionFitness, description: String(localized: "Motion classifier detects automotive activity"), rawValue: String(localized: "Automotive = true"), weight: 0.5)) }
        if speedMph > 10 { evidenceItems.append(Evidence(id: UUID(), permissionType: .locationWhenInUse, description: String(localized: "GPS speed indicates vehicle movement"), rawValue: String(format: "%.0f mph", speedMph), weight: 0.3)) }
        if hasCourse { evidenceItems.append(Evidence(id: UUID(), permissionType: .locationWhenInUse, description: String(localized: "GPS course is consistent"), rawValue: String(format: "%.0f°", snapshot.locationCourse), weight: 0.2)) }

        let isDriving = isAutomotive && speedMph > 10
        let signalCount = (isAutomotive ? 1 : 0) + (speedMph > 10 ? 1 : 0) + (hasCourse ? 1 : 0)
        let confidence: Confidence = signalCount >= 3 ? .high : signalCount >= 2 ? .medium : signalCount >= 1 ? .low : .veryLow

        let value: InferenceValue
        if isDriving {
            let speedDesc = speedMph > 55 ? String(localized: "~\(Int(speedMph)) mph / likely highway") : speedMph > 25 ? String(localized: "~\(Int(speedMph)) mph / likely city driving") : String(localized: "~\(Int(speedMph)) mph / slow traffic")
            value = .text(String(localized: "Currently driving — \(speedDesc)"))
        } else if isAutomotive {
            value = .text(String(localized: "In a vehicle (possibly a passenger)"))
        } else {
            value = .text(String(localized: "Not driving"))
        }

        return Inference(
            id: UUID(), category: .behavioral, type: .currentlyDriving,
            label: String(localized: "Driving State (Inferred)"), value: value,
            confidence: confidence, confidenceReason: String(localized: "\(signalCount) corroborating signals"),
            evidence: evidenceItems,
            methodology: String(localized: "Combines CMMotionActivity.automotive state with GPS speed > 10 mph and consistent GPS course heading."),
            databrokerNote: String(localized: "Driving detection enables audio-only ad formats and suppresses visually-complex ads. It also feeds automotive purchase intent models."),
            permissionsRequired: [.motionFitness, .locationWhenInUse], isRealTime: true, lastUpdated: now
        )
    }
}
