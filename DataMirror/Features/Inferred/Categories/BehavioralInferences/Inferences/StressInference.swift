import Foundation

/// Infers stress level from multiple weak device signals. Always .veryLow confidence.
enum StressInference {
    static let disclaimer = String(localized: "Stress inference from device sensors is speculative and not medically validated. This demonstrates the type of inference advertisers attempt — not a health assessment.")

    static func compute(snapshot: BehavioralSensorSnapshot, devicePickups: Int) -> Inference {
        let now = Date()
        var evidenceItems: [Evidence] = []
        var stressScore: Double = 0

        let hour = Calendar.current.component(.hour, from: now)
        let isLateNight = hour >= 23 || hour <= 5

        if isLateNight {
            stressScore += 25
            evidenceItems.append(Evidence(id: UUID(), permissionType: .motionFitness, description: String(localized: "Late night device use correlates with stress"), rawValue: String(localized: "Active at \(hour):00"), weight: 0.25))
        }

        if let accel = snapshot.accelerometerData {
            let magnitude = sqrt(accel.x * accel.x + accel.y * accel.y + accel.z * accel.z)
            let deviation = abs(magnitude - 1.0)
            if deviation > 0.3 {
                stressScore += 20
                evidenceItems.append(Evidence(id: UUID(), permissionType: .motionFitness, description: String(localized: "Elevated micro-movements detected"), rawValue: String(format: "Deviation: %.2fg", deviation), weight: 0.2))
            }
        }

        if devicePickups > 15 {
            stressScore += 30
            evidenceItems.append(Evidence(id: UUID(), permissionType: .motionFitness, description: String(localized: "Frequent device pickups in the last hour"), rawValue: String(localized: "\(devicePickups) pickups/hour"), weight: 0.3))
        } else if devicePickups > 8 {
            stressScore += 15
            evidenceItems.append(Evidence(id: UUID(), permissionType: .motionFitness, description: String(localized: "Moderate device pickup frequency"), rawValue: String(localized: "\(devicePickups) pickups/hour"), weight: 0.15))
        }

        let stressLevel: String
        switch stressScore {
        case 0..<25: stressLevel = String(localized: "Low")
        case 25..<50: stressLevel = String(localized: "Moderate")
        default: stressLevel = String(localized: "Elevated")
        }

        return Inference(
            id: UUID(), category: .psychographic, type: .stressLevel,
            label: String(localized: "Stress Level (Inferred)"), value: .text(stressLevel),
            confidence: .veryLow, confidenceReason: String(localized: "Stress inference from device sensors is inherently unreliable — shown for educational purposes only"),
            evidence: evidenceItems,
            methodology: String(localized: "Combines late-night phone use, accelerometer micro-movement variance, and device pickup frequency. Weighted sum bucketed into Low/Moderate/Elevated."),
            databrokerNote: String(localized: "Emotional state at time of impression affects ad conversion. 'Emotional targeting' is a documented practice in programmatic advertising, controversial but widespread."),
            permissionsRequired: [.motionFitness], isRealTime: true, lastUpdated: now
        )
    }
}
