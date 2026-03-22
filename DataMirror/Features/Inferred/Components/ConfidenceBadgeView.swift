import SwiftUI

/// A small pill displaying the confidence level with color coding.
struct ConfidenceBadgeView: View {
    let confidence: Confidence

    private var color: Color {
        switch confidence {
        case .veryHigh: return .green
        case .high: return .teal
        case .medium: return .yellow
        case .low: return .orange
        case .veryLow: return .red
        }
    }

    var body: some View {
        Text(confidence.displayName)
            .font(.caption2.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15), in: Capsule())
            .foregroundStyle(color)
            .accessibilityLabel(String(localized: "Confidence: \(confidence.displayName)"))
    }
}
