import Foundation

/// Infers sleep schedule from device inactivity patterns.
enum SleepScheduleInference: InferenceComputable {
    static let inferenceType: InferenceType = .sleepSchedule
    static let requiredPermissions: [PermissionType] = [.motionFitness]

    static func compute(from context: InferenceContext) async -> Inference {
        let now = Date()
        if let locations = context.locationHistory, locations.count >= 20 {
            let calendar = Calendar.current
            let sortedByTime = locations.sorted { $0.timestamp < $1.timestamp }
            var longestGapStart: Date?
            var longestGapEnd: Date?
            var longestGapDuration: TimeInterval = 0

            for i in 0..<(sortedByTime.count - 1) {
                let current = sortedByTime[i]
                let next = sortedByTime[i + 1]
                let gap = next.timestamp.timeIntervalSince(current.timestamp)
                let hour = calendar.component(.hour, from: current.timestamp)
                let isNightWindow = hour >= 20 || hour <= 10

                if gap > longestGapDuration && isNightWindow && gap > 3600 {
                    longestGapDuration = gap
                    longestGapStart = current.timestamp
                    longestGapEnd = next.timestamp
                }
            }

            if let sleepStart = longestGapStart, let _ = longestGapEnd, longestGapDuration > 4 * 3600 {
                let sleepComponents = calendar.dateComponents([.hour, .minute], from: sleepStart)
                let hoursSlept = longestGapDuration / 3600
                let baseDate = calendar.startOfDay(for: now)

                let normalizedSleep = calendar.date(from: DateComponents(
                    year: calendar.component(.year, from: baseDate),
                    month: calendar.component(.month, from: baseDate),
                    day: calendar.component(.day, from: baseDate),
                    hour: sleepComponents.hour ?? 22, minute: sleepComponents.minute ?? 30
                )) ?? now
                let normalizedWake = normalizedSleep.addingTimeInterval(longestGapDuration)

                let evidence = [Evidence(id: UUID(), permissionType: .motionFitness, description: String(localized: "Longest device inactivity gap during night hours"), rawValue: String(format: "%.1f hours", hoursSlept), weight: 0.7)]

                return Inference(
                    id: UUID(), category: .health, type: .sleepSchedule,
                    label: String(localized: "Sleep Schedule (Estimated)"), value: .timeRange(normalizedSleep, normalizedWake),
                    confidence: .medium, confidenceReason: String(localized: "Estimated from device inactivity — this is an approximation"),
                    evidence: evidence,
                    methodology: String(localized: "Finds the longest gap in device activity during nighttime hours (8 PM – 10 AM). The start and end approximate sleep and wake times."),
                    databrokerNote: String(localized: "Sleep schedule informs the optimal time-of-day to serve ads and correlates with health and lifestyle segment membership."),
                    permissionsRequired: [.motionFitness], isRealTime: false, lastUpdated: now
                )
            }
        }

        return Inference(
            id: UUID(), category: .health, type: .sleepSchedule,
            label: String(localized: "Sleep Schedule (Estimated)"), value: .unknown,
            confidence: .veryLow, confidenceReason: String(localized: "Insufficient device activity data"),
            evidence: [],
            methodology: String(localized: "Finds the longest gap in device activity during nighttime hours (8 PM – 10 AM)."),
            databrokerNote: String(localized: "Sleep schedule informs the optimal time-of-day to serve ads and correlates with health and lifestyle segment membership."),
            permissionsRequired: [.motionFitness], isRealTime: false, lastUpdated: now
        )
    }
}
