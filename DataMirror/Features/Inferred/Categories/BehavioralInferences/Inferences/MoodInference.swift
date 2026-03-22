import Foundation
import CoreMotion

/// Infers mood from activity state, time of day, and movement energy. Always .veryLow confidence.
enum MoodInference {
    static let disclaimer = String(localized: "Mood inference from device sensors is experimental and not validated. Shown for educational purposes only.")

    static func compute(activity: CMMotionActivity?, snapshot: BehavioralSensorSnapshot) -> Inference {
        let now = Date()
        var evidenceItems: [Evidence] = []

        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: now)
        let weekday = calendar.component(.weekday, from: now)
        let isWeekend = weekday == 1 || weekday == 7
        let isStationary = activity?.stationary ?? true
        let isLateNight = hour >= 23 || hour <= 4
        let isMorning = hour >= 6 && hour <= 10

        let movementEnergy: Double = {
            guard let accel = snapshot.accelerometerData else { return 1.0 }
            return sqrt(accel.x * accel.x + accel.y * accel.y + accel.z * accel.z)
        }()

        let mood: String
        if isMorning && (activity?.running == true || activity?.cycling == true) {
            mood = String(localized: "Alert & Active")
            evidenceItems.append(Evidence(id: UUID(), permissionType: .motionFitness, description: String(localized: "Morning exercise detected"), rawValue: String(localized: "Morning + active"), weight: 0.4))
        } else if isLateNight && isStationary {
            mood = String(localized: "Fatigued")
            evidenceItems.append(Evidence(id: UUID(), permissionType: .motionFitness, description: String(localized: "Late night stationary use"), rawValue: String(localized: "\(hour):00 + stationary"), weight: 0.3))
        } else if isWeekend && isStationary && !isLateNight {
            mood = String(localized: "Relaxed")
            evidenceItems.append(Evidence(id: UUID(), permissionType: .motionFitness, description: String(localized: "Weekend with low activity"), rawValue: String(localized: "Weekend + stationary"), weight: 0.3))
        } else if movementEnergy > 1.5 {
            mood = String(localized: "Alert & Active")
            evidenceItems.append(Evidence(id: UUID(), permissionType: .motionFitness, description: String(localized: "High-energy movement detected"), rawValue: String(format: "%.2fg", movementEnergy), weight: 0.4))
        } else if !isStationary || movementEnergy > 1.3 {
            mood = String(localized: "Restless")
            evidenceItems.append(Evidence(id: UUID(), permissionType: .motionFitness, description: String(localized: "Elevated movement while stationary"), rawValue: String(format: "%.2fg", movementEnergy), weight: 0.3))
        } else if !isLateNight && movementEnergy < 1.1 {
            mood = String(localized: "Focused")
            evidenceItems.append(Evidence(id: UUID(), permissionType: .motionFitness, description: String(localized: "Low movement during active hours"), rawValue: String(format: "%.2fg", movementEnergy), weight: 0.3))
        } else {
            mood = String(localized: "Relaxed")
            evidenceItems.append(Evidence(id: UUID(), permissionType: .motionFitness, description: String(localized: "Default state"), rawValue: String(localized: "Baseline"), weight: 0.2))
        }

        return Inference(
            id: UUID(), category: .psychographic, type: .mood,
            label: String(localized: "Mood (Inferred)"), value: .text(mood),
            confidence: .veryLow, confidenceReason: String(localized: "Mood inference from device sensors is speculative — shown to demonstrate what advertisers attempt"),
            evidence: evidenceItems,
            methodology: String(localized: "Combines time-of-day context, weekend vs weekday, current activity state, and accelerometer movement energy. These are weak correlations at best."),
            databrokerNote: String(localized: "Mood-based ad targeting is an emerging practice. Meta's internal research on emotion detection from user behavior was widely reported in 2017. This is the on-device version of that concept."),
            permissionsRequired: [.motionFitness], isRealTime: true, lastUpdated: now
        )
    }
}
