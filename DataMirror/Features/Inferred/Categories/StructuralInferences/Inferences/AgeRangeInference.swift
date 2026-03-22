import Foundation

/// Infers the user's age range from contact data and photo history.
enum AgeRangeInference: InferenceComputable {
    static let inferenceType: InferenceType = .ageRange
    static let requiredPermissions: [PermissionType] = [.contacts, .photosReadWrite]

    static func compute(from context: InferenceContext) async -> Inference {
        let now = Date()
        var evidenceItems: [Evidence] = []
        var estimatedAge: Int?
        var confidence: Confidence = .veryLow
        var confidenceReason = String(localized: "Insufficient data to estimate age")

        if let contacts = context.contacts {
            let selfContacts = contacts.filter { $0.note.lowercased().contains("me") || $0.note.lowercased().contains("my card") }
            for selfContact in selfContacts {
                if let birthday = selfContact.birthday, let birthDate = Calendar.current.date(from: birthday) {
                    let age = Calendar.current.dateComponents([.year], from: birthDate, to: now).year ?? 0
                    estimatedAge = age
                    confidence = .high
                    confidenceReason = String(localized: "Birthday found in contact card")
                    evidenceItems.append(Evidence(id: UUID(), permissionType: .contacts, description: String(localized: "Contact card with birthday"), rawValue: String(localized: "Age ~\(age)"), weight: 0.95))
                    break
                }
            }
        }

        if estimatedAge == nil, let photos = context.photoAssets, !photos.isEmpty {
            let sortedByDate = photos.compactMap(\.creationDate).sorted()
            if let oldest = sortedByDate.first {
                let yearsOnDevice = Calendar.current.dateComponents([.year], from: oldest, to: now).year ?? 0
                estimatedAge = 15 + yearsOnDevice + 5
                confidence = .low
                confidenceReason = String(localized: "Estimated from photo library history spanning \(yearsOnDevice) years")
                evidenceItems.append(Evidence(id: UUID(), permissionType: .photosReadWrite, description: String(localized: "Photo library spans \(yearsOnDevice) years"), rawValue: oldest.formatted(date: .abbreviated, time: .omitted), weight: 0.4))
            }
        }

        if estimatedAge == nil, let contacts = context.contacts, !contacts.isEmpty {
            let contactsWithBirthdays = contacts.compactMap { contact -> Int? in
                guard let birthday = contact.birthday, let birthDate = Calendar.current.date(from: birthday) else { return nil }
                return Calendar.current.dateComponents([.year], from: birthDate, to: now).year
            }
            if contactsWithBirthdays.count >= 5 {
                let averageAge = contactsWithBirthdays.reduce(0, +) / contactsWithBirthdays.count
                estimatedAge = averageAge
                confidence = .veryLow
                confidenceReason = String(localized: "Rough estimate from contact birthday distribution")
                evidenceItems.append(Evidence(id: UUID(), permissionType: .contacts, description: String(localized: "Average age of \(contactsWithBirthdays.count) contacts with birthdays"), rawValue: String(localized: "~\(averageAge) years"), weight: 0.2))
            }
        }

        let value: InferenceValue
        if let age = estimatedAge {
            let bracket: (String, String) = switch age {
            case ..<18: ("13", "17")
            case 18..<25: ("18", "24")
            case 25..<35: ("25", "34")
            case 35..<45: ("35", "44")
            case 45..<55: ("45", "54")
            case 55..<65: ("55", "64")
            default: ("65", "+")
            }
            value = .range(bracket.0, bracket.1)
        } else {
            value = .unknown
        }

        return Inference(
            id: UUID(), category: .identity, type: .ageRange,
            label: String(localized: "Age Range (Estimated)"), value: value,
            confidence: confidence, confidenceReason: confidenceReason, evidence: evidenceItems,
            methodology: String(localized: "Checks contacts for a self-referencing card with a birthday. Falls back to estimating age from the oldest photo in the library. Last resort: averages the ages of contacts with birthdays."),
            databrokerNote: String(localized: "Age bracket is required for COPPA compliance and is the second most-used demographic targeting dimension after gender."),
            permissionsRequired: [.contacts, .photosReadWrite], isRealTime: false, lastUpdated: now
        )
    }
}
