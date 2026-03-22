import SwiftUI
import ComposableArchitecture

struct AboutView: View {
    let store: StoreOf<AboutFeature>

    private let principles: [(String, String)] = [
        ("lock.shield.fill", String(localized: "All data stays on your device. Nothing is sent anywhere.")),
        ("eye.slash.fill", String(localized: "No analytics, no tracking, no advertising of any kind.")),
        ("hand.raised.fill", String(localized: "Permissions are never requested automatically — only when you tap.")),
        ("info.circle.fill", String(localized: "This app is purely informational. It cannot block or change what other apps do.")),
    ]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 12) {
                            Image(systemName: "mirrorball")
                                .font(.system(size: 44))
                                .foregroundStyle(.blue)
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(String(localized: "DataMirror"))
                                    .font(.title2.bold())
                                Text(String(localized: "Version \(store.appVersion)"))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Text(String(localized: "DataMirror shows you exactly what sensor data your iPhone exposes and what your current permissions unlock — so you can make informed decisions, not fearful ones."))
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                }

                Section(String(localized: "Our Principles")) {
                    ForEach(principles, id: \.0) { symbol, text in
                        Label(text, systemImage: symbol)
                            .font(.subheadline)
                    }
                }

                Section(String(localized: "What We Cannot Do")) {
                    Label(String(localized: "Block apps from collecting data they're permitted to access."), systemImage: "xmark.circle")
                        .font(.subheadline)
                    Label(String(localized: "Show you data other apps have already collected."), systemImage: "xmark.circle")
                        .font(.subheadline)
                    Label(String(localized: "Guarantee that revoking a permission stops prior data use."), systemImage: "xmark.circle")
                        .font(.subheadline)
                }

                Section(String(localized: "Sensor Data That Can't Be Blocked")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(String(localized: "The following are readable by any app with no permission required:"))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        let alwaysOn = [
                            String(localized: "IP address (visible to every server you connect to)"),
                            String(localized: "Device model and OS version"),
                            String(localized: "Screen resolution and display scale"),
                            String(localized: "Timezone and locale"),
                            String(localized: "Battery level and charging state"),
                        ]
                        ForEach(alwaysOn, id: \.self) { item in
                            Label(item, systemImage: "circle.fill")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .labelStyle(.titleAndIcon)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section {
                    Text(String(localized: "DataMirror is built with The Composable Architecture by Point-Free. All source code is available for review."))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(String(localized: "About"))
        }
    }
}

#Preview {
    AboutView(
        store: Store(initialState: AboutFeature.State()) {
            AboutFeature()
        }
    )
}
