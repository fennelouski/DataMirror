import SwiftUI

/// Displays the evidence items that contributed to an inference.
struct EvidenceListView: View {
    let evidence: [Evidence]

    var body: some View {
        ForEach(evidence) { item in
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: sfSymbol(for: item.permissionType))
                        .foregroundStyle(.secondary)
                        .font(.caption)
                        .accessibilityHidden(true)
                    Text(permissionName(item.permissionType))
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                }

                Text(item.description)
                    .font(.subheadline)

                Text(item.rawValue)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color(.systemGray5))
                            .frame(height: 4)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.accentColor)
                            .frame(width: geometry.size.width * item.weight, height: 4)
                    }
                }
                .frame(height: 4)
                .accessibilityLabel(String(localized: "Weight: \(Int(item.weight * 100))%"))
            }
            .padding(.vertical, 4)
        }
    }

    private func sfSymbol(for type: PermissionType) -> String {
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

    private func permissionName(_ type: PermissionType) -> String {
        switch type {
        case .locationWhenInUse: return String(localized: "Location")
        case .locationAlways: return String(localized: "Location (Always)")
        case .contacts: return String(localized: "Contacts")
        case .photosReadWrite: return String(localized: "Photos")
        case .motionFitness: return String(localized: "Motion & Fitness")
        case .healthRead: return String(localized: "Health (Read)")
        case .tracking: return String(localized: "Tracking")
        default: return type.rawValue
        }
    }
}
