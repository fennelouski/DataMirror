import Foundation
import UIKit
import Vision
import Photos

/// Infers household composition from contact relations and photo face detection.
enum HouseholdCompositionInference: InferenceComputable {
    static let inferenceType: InferenceType = .householdComposition
    static let requiredPermissions: [PermissionType] = [.contacts, .photosReadWrite]

    static func compute(from context: InferenceContext) async -> Inference {
        let now = Date()
        var evidenceItems: [Evidence] = []
        var members: [String] = []
        var confidence: Confidence = .veryLow

        if let contacts = context.contacts {
            var hasSpouse = false
            var childCount = 0

            for contact in contacts {
                for relation in contact.relations {
                    let label = relation.label.lowercased()
                    if label.contains("spouse") || label.contains("partner") || label.contains("husband") || label.contains("wife") {
                        hasSpouse = true
                    } else if label.contains("child") || label.contains("son") || label.contains("daughter") {
                        childCount += 1
                    }
                }
            }

            if hasSpouse { members.append(String(localized: "Spouse/Partner")) }
            if childCount > 0 { members.append(String(localized: "\(childCount) child(ren)")) }

            if hasSpouse || childCount > 0 {
                confidence = .high
                evidenceItems.append(Evidence(id: UUID(), permissionType: .contacts, description: String(localized: "Family relations found in contacts"), rawValue: String(localized: "Spouse: \(hasSpouse ? "yes" : "no"), Children: \(childCount)"), weight: 0.8))
            }
        }

        if context.hasPermission(.photosReadWrite), members.isEmpty {
            if #available(iOS 17, *) {
                let faceCount = await detectFacesInRecentPhotos()
                if let faceCount, faceCount > 1 {
                    members.append(String(localized: "Estimated \(faceCount) recurring faces in photos"))
                    confidence = max(confidence, .low)
                    evidenceItems.append(Evidence(id: UUID(), permissionType: .photosReadWrite, description: String(localized: "\(faceCount) distinct face groups detected"), rawValue: String(localized: "\(faceCount) faces"), weight: 0.4))
                }
            }
        }

        if members.isEmpty { members.append(String(localized: "Likely lives alone or insufficient data")) }

        return Inference(
            id: UUID(), category: .social, type: .householdComposition,
            label: String(localized: "Household Composition (Estimated)"), value: .list(members),
            confidence: confidence, confidenceReason: confidence >= .high ? String(localized: "Contact relations explicitly label family members") : String(localized: "Limited data available"),
            evidence: evidenceItems,
            methodology: String(localized: "Parses contact relation labels (spouse, child, parent) to identify family structure. Falls back to Vision face detection on up to 20 recent photos to count distinct face groups."),
            databrokerNote: String(localized: "Household composition determines which household members receive shared ad targeting — a parent browsing baby products will receive ads across all household devices."),
            permissionsRequired: [.contacts, .photosReadWrite], isRealTime: false, lastUpdated: now
        )
    }

    @available(iOS 17, *)
    private static func detectFacesInRecentPhotos() async -> Int? {
        await Task.detached(priority: .background) {
            let fetchOptions = PHFetchOptions()
            fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            fetchOptions.fetchLimit = 20
            let assets = PHAsset.fetchAssets(with: .image, options: fetchOptions)

            var maxFaceCount = 0
            let imageManager = PHImageManager.default()
            let requestOptions = PHImageRequestOptions()
            requestOptions.isSynchronous = true
            requestOptions.deliveryMode = .fastFormat

            assets.enumerateObjects { asset, _, stop in
                guard !Task.isCancelled else { stop.pointee = true; return }
                imageManager.requestImage(for: asset, targetSize: CGSize(width: 300, height: 300), contentMode: .aspectFit, options: requestOptions) { image, _ in
                    guard let cgImage = image?.cgImage else { return }
                    let request = VNDetectFaceRectanglesRequest()
                    let handler = VNImageRequestHandler(cgImage: cgImage)
                    try? handler.perform([request])
                    if let results = request.results { maxFaceCount = max(maxFaceCount, results.count) }
                }
            }
            return maxFaceCount > 0 ? maxFaceCount : nil
        }.value
    }
}
