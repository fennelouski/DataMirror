import SwiftUI
import ComposableArchitecture

struct PrimerView: View {
    let store: StoreOf<PrimerFeature>

    private let features: [(symbol: String, title: String, subtitle: String)] = [
        (
            "eye",
            String(localized: "Live Sensor Dashboard"),
            String(localized: "See every data signal your device is broadcasting right now")
        ),
        (
            "slider.horizontal.3",
            String(localized: "Permission Explorer"),
            String(localized: "Understand what each permission unlocks for apps and advertisers")
        ),
        (
            "chart.bar.fill",
            String(localized: "Exposure Score"),
            String(localized: "Know how much data surface you expose compared to your choices")
        ),
    ]

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "lock.shield.fill")
                .font(.system(size: 72))
                .foregroundStyle(Color.accentColor)
                .accessibilityHidden(true)

            VStack(spacing: 8) {
                Text(String(localized: "DataMirror"))
                    .font(.largeTitle.bold())
                Text(String(localized: "See exactly what your iPhone shares"))
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: 20) {
                ForEach(features, id: \.symbol) { feature in
                    HStack(spacing: 16) {
                        Image(systemName: feature.symbol)
                            .font(.title2)
                            .foregroundStyle(Color.accentColor)
                            .frame(width: 36)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(feature.title)
                                .font(.headline)
                            Text(feature.subtitle)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            .padding(.horizontal, 24)

            Spacer()

            Text(String(localized: "DataMirror never collects, stores, or transmits any of your data. Everything stays on your device."))
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button {
                store.send(.getStartedTapped)
            } label: {
                Text(String(localized: "Get Started"))
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
            .accessibilityHint(String(localized: "Dismisses this screen and opens the dashboard"))
        }
    }
}

#Preview {
    PrimerView(
        store: Store(initialState: PrimerFeature.State()) {
            PrimerFeature()
        } withDependencies: {
            $0.userDefaults = .testValue
        }
    )
}
