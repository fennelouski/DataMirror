import Foundation

// MARK: - InferenceType

/// Identifies a specific inference computation.
enum InferenceType: String, Equatable, Sendable, CaseIterable {
    // Structural
    case homeAddress
    case workAddress
    case incomeBracket
    case ageRange
    case householdComposition
    case relationshipStatus
    case commutePattern
    case sleepSchedule
    case petOwner

    // Behavioral
    case currentActivity
    case currentlyDriving
    case exercisePattern
    case currentlyWorking
    case stressLevel
    case mood

    var sfSymbol: String {
        switch self {
        case .homeAddress: "house.fill"
        case .workAddress: "building.2.fill"
        case .incomeBracket: "dollarsign.circle.fill"
        case .ageRange: "person.fill"
        case .householdComposition: "person.3.fill"
        case .relationshipStatus: "heart.fill"
        case .commutePattern: "car.fill"
        case .sleepSchedule: "moon.zzz.fill"
        case .petOwner: "pawprint.fill"
        case .currentActivity: "figure.walk"
        case .currentlyDriving: "car.fill"
        case .exercisePattern: "figure.run"
        case .currentlyWorking: "desktopcomputer"
        case .stressLevel: "brain.head.profile"
        case .mood: "face.smiling"
        }
    }
}

// MARK: - InferenceCategory

/// Groups inferences for display.
enum InferenceCategory: String, CaseIterable, Equatable, Sendable {
    case identity = "Identity"
    case location = "Location & Routines"
    case financial = "Financial"
    case social = "Social & Household"
    case behavioral = "Behavior & Activity"
    case health = "Health & Wellness"
    case psychographic = "Psychographic"

    var displayName: String { rawValue }
}

// MARK: - InferenceValue

/// The inferred result, typed for display.
enum InferenceValue: Equatable, Sendable {
    case text(String)
    case range(String, String)
    case percentage(Double)
    case coordinate(Double, Double)
    case timeRange(Date, Date)
    case list([String])
    case unknown

    var displayString: String {
        switch self {
        case let .text(s): return s
        case let .range(lo, hi): return "\(lo) – \(hi)"
        case let .percentage(p): return "\(Int(p * 100))% likely"
        case let .coordinate(lat, lon): return String(format: "%.4f°, %.4f°", lat, lon)
        case let .timeRange(start, end):
            let fmt = DateFormatter()
            fmt.dateFormat = "h:mm a"
            return "~\(fmt.string(from: start)) – ~\(fmt.string(from: end))"
        case let .list(items): return items.joined(separator: ", ")
        case .unknown: return "Insufficient data"
        }
    }
}

// MARK: - Confidence

/// How certain the inference is.
enum Confidence: Int, Comparable, Equatable, Sendable, CaseIterable {
    case veryLow = 1
    case low = 2
    case medium = 3
    case high = 4
    case veryHigh = 5

    nonisolated static func < (lhs: Confidence, rhs: Confidence) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var displayName: String {
        switch self {
        case .veryLow: return String(localized: "Very Low")
        case .low: return String(localized: "Low")
        case .medium: return String(localized: "Medium")
        case .high: return String(localized: "High")
        case .veryHigh: return String(localized: "Very High")
        }
    }

    var accuracyRange: String {
        switch self {
        case .veryLow: return "<40%"
        case .low: return "40–60%"
        case .medium: return "60–80%"
        case .high: return "80–95%"
        case .veryHigh: return ">95%"
        }
    }
}

// MARK: - Inference

/// A single inferred fact about the user, with full provenance.
struct Inference: Equatable, Identifiable, Sendable {
    let id: UUID
    let category: InferenceCategory
    let type: InferenceType
    let label: String
    let value: InferenceValue
    let confidence: Confidence
    let confidenceReason: String
    let evidence: [Evidence]
    let methodology: String
    let databrokerNote: String
    let permissionsRequired: [PermissionType]
    let isRealTime: Bool
    let lastUpdated: Date
}
