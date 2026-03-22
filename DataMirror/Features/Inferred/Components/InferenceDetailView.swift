import SwiftUI

/// Full detail view for a single inference, showing methodology, evidence, and data broker context.
struct InferenceDetailView: View {
    let inference: Inference

    var body: some View {
        List {
            Section {
                VStack(alignment: .center, spacing: 12) {
                    Image(systemName: inference.type.sfSymbol)
                        .font(.system(size: 48))
                        .foregroundStyle(Color.accentColor)
                        .accessibilityHidden(true)
                    Text(inference.label)
                        .font(.title3.bold())
                        .multilineTextAlignment(.center)
                    Text(inference.value.displayString)
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)
                    ConfidenceBadgeView(confidence: inference.confidence)
                    Text(inference.confidenceReason)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }

            if inference.confidence <= .low {
                Section {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 4) {
                            if inference.type == .stressLevel {
                                Text(StressInference.disclaimer).font(.caption)
                            } else if inference.type == .mood {
                                Text(MoodInference.disclaimer).font(.caption)
                            } else {
                                Text(String(localized: "This inference has \(inference.confidence.displayName.lowercased()) confidence (\(inference.confidence.accuracyRange) estimated accuracy). Treat it as a rough approximation, not a fact.")).font(.caption)
                            }
                        }
                    }
                    .padding(8)
                    .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                    .listRowBackground(Color.clear)
                }
            }

            Section(String(localized: "How We Figured This Out")) {
                Text(inference.methodology).font(.body)
            }

            if !inference.evidence.isEmpty {
                Section(String(localized: "Evidence")) {
                    EvidenceListView(evidence: inference.evidence)
                }
            }

            Section(String(localized: "Why This Matters")) {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundStyle(.yellow)
                        .accessibilityHidden(true)
                    Text(inference.databrokerNote).font(.body)
                }
                .padding(8)
                .background(Color.yellow.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                .listRowBackground(Color.clear)
            }

            Section(String(localized: "Permissions Driving This")) {
                ForEach(inference.permissionsRequired, id: \.self) { permission in
                    Label(permission.rawValue, systemImage: permissionSFSymbol(permission))
                        .font(.subheadline)
                }
            }
        }
        .navigationTitle(String(localized: "Inference Detail"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func permissionSFSymbol(_ type: PermissionType) -> String {
        switch type {
        case .locationAlways, .locationWhenInUse, .preciseLocation: return "location.fill"
        case .contacts: return "person.crop.circle.fill"
        case .photosReadWrite, .photosLimited, .photosAddOnly: return "photo.fill"
        case .motionFitness: return "figure.walk"
        case .healthRead, .healthWrite: return "heart.fill"
        case .camera: return "camera.fill"
        case .microphone: return "mic.fill"
        case .tracking: return "eye.fill"
        default: return "lock.fill"
        }
    }
}
