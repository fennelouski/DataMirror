import Foundation
import CoreMotion

/// Infers exercise patterns from motion activity.
enum ExercisePatternInference {
    static func computeBehavioral(activity: CMMotionActivity?, snapshot: BehavioralSensorSnapshot) -> Inference {
        let now = Date()
        let speedMph = snapshot.locationSpeed > 0 ? snapshot.locationSpeed * 2.237 : 0
        var evidenceItems: [Evidence] = []
        let value: InferenceValue
        let confidence: Confidence

        if let activity, (activity.running || activity.cycling) {
            value = .text(String(localized: "Currently exercising"))
            confidence = .high
            evidenceItems.append(Evidence(id: UUID(), permissionType: .motionFitness, description: String(localized: "Motion classifier detects active exercise"), rawValue: activity.running ? String(localized: "Running") : String(localized: "Cycling"), weight: 0.8))
        } else if activity?.walking == true && speedMph > 3 {
            value = .text(String(localized: "Currently active (walking)"))
            confidence = .medium
            evidenceItems.append(Evidence(id: UUID(), permissionType: .motionFitness, description: String(localized: "Walking detected"), rawValue: String(format: "%.1f mph", speedMph), weight: 0.5))
        } else {
            value = .text(String(localized: "Currently sedentary"))
            confidence = .medium
            evidenceItems.append(Evidence(id: UUID(), permissionType: .motionFitness, description: String(localized: "Stationary or minimal movement"), rawValue: String(localized: "Stationary"), weight: 0.5))
        }

        return Inference(
            id: UUID(), category: .health, type: .exercisePattern,
            label: String(localized: "Exercise State (Inferred)"), value: value,
            confidence: confidence, confidenceReason: String(localized: "Based on current motion classifier output and GPS speed"),
            evidence: evidenceItems,
            methodology: String(localized: "Combines CMMotionActivity classification with GPS speed to determine current exercise state."),
            databrokerNote: String(localized: "Exercise frequency is a top predictor of health insurance risk models and premium supplement purchase intent."),
            permissionsRequired: [.motionFitness, .locationWhenInUse], isRealTime: true, lastUpdated: now
        )
    }
}
