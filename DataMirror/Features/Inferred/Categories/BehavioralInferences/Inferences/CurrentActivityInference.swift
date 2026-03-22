import Foundation
import CoreMotion

/// Infers current activity state from CMMotionActivity.
enum CurrentActivityInference {
    static func compute(activity: CMMotionActivity?, snapshot: BehavioralSensorSnapshot) -> Inference {
        let now = Date()
        guard let activity else {
            return makeResult(value: .unknown, confidence: .veryLow, confidenceReason: String(localized: "Motion activity data not available"), evidence: [], now: now)
        }

        let activityName: String
        if activity.running { activityName = String(localized: "Running") }
        else if activity.cycling { activityName = String(localized: "Cycling") }
        else if activity.automotive { activityName = String(localized: "In a vehicle") }
        else if activity.walking { activityName = String(localized: "Walking") }
        else { activityName = String(localized: "Stationary") }

        let confidence: Confidence = switch activity.confidence {
        case .high: .high
        case .medium: .medium
        case .low: .low
        @unknown default: .veryLow
        }

        let evidence = [Evidence(id: UUID(), permissionType: .motionFitness, description: String(localized: "Apple on-device motion classifier"), rawValue: activityName, weight: 1.0)]
        return makeResult(value: .text(activityName), confidence: confidence, confidenceReason: String(localized: "Apple's on-device neural network classifies motion"), evidence: evidence, now: now)
    }

    private static func makeResult(value: InferenceValue, confidence: Confidence, confidenceReason: String, evidence: [Evidence], now: Date) -> Inference {
        Inference(
            id: UUID(), category: .behavioral, type: .currentActivity,
            label: String(localized: "Current Activity (Inferred)"), value: value,
            confidence: confidence, confidenceReason: confidenceReason, evidence: evidence,
            methodology: String(localized: "Uses Apple's CMMotionActivity classifier, which runs an on-device neural network on accelerometer and gyroscope data."),
            databrokerNote: String(localized: "Activity state at time of ad impression doubles click-through rates when matched to ad creative (e.g. showing a protein bar ad to someone who just finished running)."),
            permissionsRequired: [.motionFitness], isRealTime: true, lastUpdated: now
        )
    }
}
