import Foundation
import UIKit

/// Infers income bracket from multiple signals: ZIP code, device model, travel patterns.
enum IncomeBracketInference: InferenceComputable {
    static let inferenceType: InferenceType = .incomeBracket
    static let requiredPermissions: [PermissionType] = [.locationWhenInUse, .photosReadWrite]

    static func compute(from context: InferenceContext) async -> Inference {
        let now = Date()
        var evidenceItems: [Evidence] = []
        var signals: [(income: Int, weight: Double)] = []

        let deviceModel = UIDevice.current.name
        let isProModel = deviceModel.lowercased().contains("pro")
        signals.append((isProModel ? 95_000 : 65_000, 0.15))
        evidenceItems.append(Evidence(
            id: UUID(), permissionType: .tracking,
            description: String(localized: "Device model indicates \(isProModel ? "premium" : "standard") tier"),
            rawValue: deviceModel, weight: 0.15
        ))

        if let locations = context.locationHistory, !locations.isEmpty {
            let overnightLocations = CoordinateCluster.filter(locations, startHour: 22, endHour: 6)
            let clusters = CoordinateCluster.cluster(overnightLocations)
            if let home = clusters.first {
                if let zip = await StructuralInferenceEngine.shared.zipCode(latitude: home.latitude, longitude: home.longitude) {
                    if let medianIncome = ZIPIncomeData.lookup[zip] {
                        signals.append((medianIncome, 0.45))
                        evidenceItems.append(Evidence(
                            id: UUID(), permissionType: .locationWhenInUse,
                            description: String(localized: "Home ZIP code \(zip) median household income"),
                            rawValue: "$\(medianIncome.formatted())", weight: 0.45
                        ))
                    }
                }
            }
        }

        if let photos = context.photoAssets {
            let uniqueLocations = Set(photos.compactMap { photo -> String? in
                guard let loc = photo.location else { return nil }
                return String(format: "%.1f,%.1f", loc.latitude, loc.longitude)
            })
            if uniqueLocations.count > 20 {
                signals.append((110_000, 0.2))
                evidenceItems.append(Evidence(
                    id: UUID(), permissionType: .photosReadWrite,
                    description: String(localized: "Photos at \(uniqueLocations.count) distinct locations suggest frequent travel"),
                    rawValue: String(localized: "\(uniqueLocations.count) unique photo locations"), weight: 0.2
                ))
            } else if uniqueLocations.count > 10 {
                signals.append((85_000, 0.1))
                evidenceItems.append(Evidence(
                    id: UUID(), permissionType: .photosReadWrite,
                    description: String(localized: "Photos at \(uniqueLocations.count) locations suggest moderate travel"),
                    rawValue: String(localized: "\(uniqueLocations.count) unique photo locations"), weight: 0.1
                ))
            }
        }

        if context.hasPermission(.healthRead) {
            signals.append((90_000, 0.1))
            evidenceItems.append(Evidence(
                id: UUID(), permissionType: .healthRead,
                description: String(localized: "HealthKit access suggests health-conscious behavior"),
                rawValue: String(localized: "Permission granted"), weight: 0.1
            ))
        }

        guard !signals.isEmpty else {
            return Inference(
                id: UUID(), category: .financial, type: .incomeBracket,
                label: String(localized: "Income Bracket (Estimated)"), value: .unknown,
                confidence: .veryLow, confidenceReason: String(localized: "Insufficient signals"),
                evidence: [], methodology: "", databrokerNote: "",
                permissionsRequired: [.locationWhenInUse], isRealTime: false, lastUpdated: now
            )
        }

        let totalWeight = signals.reduce(0.0) { $0 + $1.weight }
        let weightedSum = signals.reduce(0.0) { $0 + Double($1.income) * $1.weight }
        let estimatedIncome = Int(weightedSum / totalWeight)
        let bracketLow = (estimatedIncome / 25_000) * 25_000
        let bracketHigh = bracketLow + 25_000
        let lowStr = bracketLow >= 200_000 ? "$200K+" : "$\(bracketLow / 1000)K"
        let highStr = bracketHigh >= 200_000 ? "$200K+" : "$\(bracketHigh / 1000)K"
        let value: InferenceValue = bracketLow >= 200_000 ? .text("$200K+") : .range(lowStr, highStr)

        return Inference(
            id: UUID(), category: .financial, type: .incomeBracket,
            label: String(localized: "Income Bracket (Estimated)"),
            value: value, confidence: .medium,
            confidenceReason: String(localized: "Multi-signal estimate combining \(signals.count) data points — income inference is inherently approximate"),
            evidence: evidenceItems,
            methodology: String(localized: "Combines ZIP code median household income, device model tier, photo location diversity as a travel proxy, and HealthKit access as a health-consciousness signal."),
            databrokerNote: String(localized: "Income brackets drive credit card offer targeting, luxury goods advertising, and political fundraising lists. Accuracy within one bracket is sufficient for most ad targeting purposes."),
            permissionsRequired: [.locationWhenInUse, .photosReadWrite, .healthRead],
            isRealTime: false, lastUpdated: now
        )
    }
}
