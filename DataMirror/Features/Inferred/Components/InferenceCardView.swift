import SwiftUI

/// Displays a single inference as a card with value, confidence, and state handling.
struct InferenceCardView: View {
    let inference: Inference
    let onTap: () -> Void

    private var isUnknown: Bool {
        if case .unknown = inference.value { return true }
        return false
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: isUnknown ? "lock.fill" : inference.type.sfSymbol)
                    .font(.title2)
                    .foregroundStyle(isUnknown ? .gray : .accentColor)
                    .frame(width: 40)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(inference.label)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if isUnknown {
                        Text(String(localized: "Gathering data..."))
                            .font(.subheadline.bold())
                            .foregroundStyle(.secondary)
                        Text(String(localized: "Check back after using the app for a while"))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .italic()
                    } else {
                        Text(inference.value.displayString)
                            .font(.subheadline.bold())
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                    }

                    Text(inference.lastUpdated, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                ConfidenceBadgeView(confidence: inference.confidence)

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "\(inference.label): \(inference.value.displayString). Confidence: \(inference.confidence.displayName)"))
        .accessibilityHint(String(localized: "Tap to see how this was inferred"))
    }
}

/// Compact behavioral card for the horizontal scroll.
struct BehavioralCardView: View {
    let inference: Inference
    let onTap: () -> Void
    @State private var isPulsing = false

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: inference.type.sfSymbol)
                        .font(.title3)
                        .foregroundStyle(Color.accentColor)
                    Spacer()
                    ConfidenceBadgeView(confidence: inference.confidence)
                }

                Text(inference.label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text(inference.value.displayString)
                    .font(.caption.bold())
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                if inference.type == .mood || inference.type == .stressLevel {
                    Text(String(localized: "Speculative — not validated"))
                        .font(.system(size: 8))
                        .foregroundStyle(.red)
                        .italic()
                }
            }
            .padding(12)
            .frame(width: 160, height: 120)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
            .scaleEffect(isPulsing ? 1.02 : 1.0)
            .animation(.easeInOut(duration: 0.3), value: isPulsing)
        }
        .buttonStyle(.plain)
        .onChange(of: inference.value) {
            isPulsing = true
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 300_000_000)
                isPulsing = false
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "\(inference.label): \(inference.value.displayString)"))
    }
}
