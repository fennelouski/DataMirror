import Foundation
import CoreMotion

/// Infers whether the user is currently at work.
enum WorkingInference {
    static func compute(activity: CMMotionActivity?, snapshot: BehavioralSensorSnapshot) -> Inference {
        let now = Date()
        var evidenceItems: [Evidence] = []
        var workSignals = 0

        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: now)
        let weekday = calendar.component(.weekday, from: now)
        let isBusinessHours = hour >= 9 && hour <= 17
        let isWeekday = weekday >= 2 && weekday <= 6

        if isBusinessHours && isWeekday {
            workSignals += 1
            evidenceItems.append(Evidence(id: UUID(), permissionType: .motionFitness, description: String(localized: "Business hours on a weekday"), rawValue: "\(hour):00", weight: 0.3))
        }

        if activity?.stationary ?? false {
            workSignals += 1
            evidenceItems.append(Evidence(id: UUID(), permissionType: .motionFitness, description: String(localized: "Device is stationary — consistent with desk work"), rawValue: String(localized: "Stationary"), weight: 0.25))
        }

        if !snapshot.isAudioActive {
            workSignals += 1
            evidenceItems.append(Evidence(id: UUID(), permissionType: .motionFitness, description: String(localized: "No audio/music playing"), rawValue: String(localized: "Audio inactive"), weight: 0.15))
        }

        let value: InferenceValue
        let confidence: Confidence
        if workSignals >= 3 { value = .text(String(localized: "Likely at work")); confidence = .medium }
        else if workSignals >= 2 && isBusinessHours { value = .text(String(localized: "Working hours, location unclear")); confidence = .low }
        else { value = .text(String(localized: "Likely not working")); confidence = .medium }

        return Inference(
            id: UUID(), category: .behavioral, type: .currentlyWorking,
            label: String(localized: "Work State (Inferred)"), value: value,
            confidence: confidence, confidenceReason: String(localized: "\(workSignals) of 3 work-state signals detected"),
            evidence: evidenceItems,
            methodology: String(localized: "Combines time-of-day (weekday 9–5), motion state (stationary), and audio state (no music). Each is a weak signal."),
            databrokerNote: String(localized: "Work-state detection suppresses ads for products employees shouldn't see at work and enables B2B ad targeting during professional decision-making windows."),
            permissionsRequired: [.motionFitness, .locationWhenInUse], isRealTime: true, lastUpdated: now
        )
    }
}
