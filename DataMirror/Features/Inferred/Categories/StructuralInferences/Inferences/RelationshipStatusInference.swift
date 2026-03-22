import Foundation

/// Infers relationship status from contact relation labels.
enum RelationshipStatusInference: InferenceComputable {
    static let inferenceType: InferenceType = .relationshipStatus
    static let requiredPermissions: [PermissionType] = [.contacts]

    static func compute(from context: InferenceContext) async -> Inference {
        let now = Date()
        var evidenceItems: [Evidence] = []
        var statusText = String(localized: "Relationship status unclear")
        var confidence: Confidence = .veryLow

        if let contacts = context.contacts {
            let partnerLabels = ["spouse", "partner", "husband", "wife"]
            var hasPartner = false

            for contact in contacts {
                for relation in contact.relations {
                    if partnerLabels.contains(where: { relation.label.lowercased().contains($0) }) {
                        hasPartner = true
                        break
                    }
                }
                if hasPartner { break }
            }

            if hasPartner {
                statusText = String(localized: "Likely in a relationship")
                confidence = .high
                evidenceItems.append(Evidence(id: UUID(), permissionType: .contacts, description: String(localized: "Contact relation labeled as spouse/partner"), rawValue: String(localized: "Partner found"), weight: 0.9))
            } else {
                statusText = String(localized: "No partner contact found — status unclear")
                confidence = .low
                evidenceItems.append(Evidence(id: UUID(), permissionType: .contacts, description: String(localized: "Scanned \(contacts.count) contacts for relationship labels"), rawValue: String(localized: "No spouse/partner labels found"), weight: 0.3))
            }
        }

        return Inference(
            id: UUID(), category: .social, type: .relationshipStatus,
            label: String(localized: "Relationship Status (Estimated)"), value: .text(statusText),
            confidence: confidence, confidenceReason: confidence >= .high ? String(localized: "Contact labeled as spouse or partner found") : String(localized: "No spouse/partner relation labels found"),
            evidence: evidenceItems,
            methodology: String(localized: "Searches contact relation labels for Spouse, Partner, Husband, or Wife entries. Absence of such labels does not confirm single status."),
            databrokerNote: String(localized: "Relationship status drives targeting for wedding vendors, dating apps (targeting singles), couples' travel, and joint financial products."),
            permissionsRequired: [.contacts], isRealTime: false, lastUpdated: now
        )
    }
}
