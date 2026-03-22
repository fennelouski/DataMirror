import SwiftUI
import ComposableArchitecture

struct DashboardView: View {
    let store: StoreOf<DashboardFeature>
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16) {
                    ExposureScoreCard(score: store.score, permissions: Array(store.permissions))

                    ForEach(store.sensorGroups) { group in
                        SensorGroupCard(group: group)
                    }

                    if store.sensorGroups.isEmpty {
                        ProgressView(String(localized: "Loading sensors…"))
                            .padding(.top, 40)
                    }
                }
                .padding()
            }
            .navigationTitle(String(localized: "Live Data"))
            .background(Color(.systemGroupedBackground))
        }
        .onAppear { store.send(.onAppear) }
        .onDisappear { store.send(.onDisappear) }
        .onChange(of: scenePhase) { _, newPhase in
            store.send(.scenePhaseChanged(newPhase))
        }
    }
}

// MARK: - Exposure Score Card

private struct ExposureScoreCard: View {
    let score: ExposureScore
    let permissions: [PermissionItem]

    private var scoreColor: Color {
        switch score.total {
        case 0..<30: .green
        case 30..<60: .yellow
        default: .red
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(String(localized: "Exposure Score"))
                .font(.headline)
                .accessibilityAddTraits(.isHeader)

            HStack(alignment: .top, spacing: 20) {
                // Circular progress
                ZStack {
                    Circle()
                        .stroke(Color(.systemGray5), lineWidth: 10)
                    Circle()
                        .trim(from: 0, to: CGFloat(score.total) / 100)
                        .stroke(scoreColor, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.6), value: score.total)
                    VStack(spacing: 2) {
                        Text("\(score.total)")
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .foregroundStyle(scoreColor)
                            .monospacedDigit()
                        Text(String(localized: "/ 100"))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 90, height: 90)
                .accessibilityLabel(String(localized: "Exposure score: \(score.total) out of 100"))
                .accessibilityValue(scoreColor == .green ? String(localized: "Low") : scoreColor == .yellow ? String(localized: "Medium") : String(localized: "High"))

                VStack(alignment: .leading, spacing: 6) {
                    subScorePill(label: String(localized: "Location"), value: score.locationScore, max: 40, color: .blue)
                    subScorePill(label: String(localized: "Identity"), value: score.identityScore, max: 30, color: .purple)
                    subScorePill(label: String(localized: "Behavioral"), value: score.behavioralScore, max: 20, color: .orange)
                    subScorePill(label: String(localized: "Device"), value: score.deviceScore, max: 20, color: .teal)
                }
            }

            Text(score.summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if !score.topThreeToRevoke.isEmpty {
                Divider()

                Text(String(localized: "Reduce Your Score"))
                    .font(.subheadline.bold())
                    .accessibilityAddTraits(.isHeader)

                let totalSavings = score.topThreeToRevoke.reduce(0) { $0 + $1.1 }

                ForEach(score.topThreeToRevoke, id: \.0) { type_, points in
                    if let item = permissions.first(where: { $0.id == type_ }) {
                        HStack {
                            Label(item.name, systemImage: item.sfSymbol)
                                .font(.footnote)
                            Spacer()
                            Text(String(localized: "−\(points) pts"))
                                .font(.caption.bold())
                                .foregroundStyle(.red)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(String(localized: "\(item.name): \(points) points"))
                    }
                }

                Text(String(localized: "Revoking these in Settings could reduce your score by \(totalSavings) points"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private func subScorePill(label: String, value: Int, max: Int, color: Color) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(width: 64, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(.systemGray5))
                    Capsule().fill(color.opacity(0.7))
                        .frame(width: max > 0 ? geo.size.width * CGFloat(value) / CGFloat(max) : 0)
                }
            }
            .frame(height: 8)
            Text("\(value)")
                .font(.caption2.bold())
                .foregroundStyle(color)
                .frame(width: 20, alignment: .trailing)
                .monospacedDigit()
        }
    }

}

// MARK: - Sensor Group Card

private struct SensorGroupCard: View {
    let group: SensorGroup

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Label(group.name, systemImage: group.sfSymbol)
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            let lockedReadings = group.readings.filter { $0.requiresPermission && $0.permissionStatus != .granted }
            let visibleReadings = group.readings.filter { !$0.requiresPermission || $0.permissionStatus == .granted }

            if !lockedReadings.isEmpty && visibleReadings.isEmpty {
                LockedSensorCard(permissionStatus: lockedReadings.first?.permissionStatus ?? .denied)
            } else {
                ForEach(visibleReadings) { reading in
                    SensorReadingRow(reading: reading)
                    if reading.id != visibleReadings.last?.id {
                        Divider().padding(.leading, 16)
                    }
                }
            }
        }
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Locked Sensor Card

private struct LockedSensorCard: View {
    let permissionStatus: PermissionStatus

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "lock.fill")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: "Permission Required"))
                    .font(.subheadline.bold())
                Text(statusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
    }

    private var statusMessage: String {
        switch permissionStatus {
        case .denied:
            String(localized: "Enable in Settings → Privacy to see live data.")
        case .notDetermined:
            String(localized: "Go to the Permissions tab to request access.")
        case .restricted:
            String(localized: "Access is restricted by your organization or parental controls.")
        default:
            String(localized: "This sensor requires a permission to read.")
        }
    }
}

// MARK: - Sensor Reading Row

private struct SensorReadingRow: View {
    let reading: SensorReading
    @State private var now = Date()

    private var relativeTime: String {
        let elapsed = now.timeIntervalSince(reading.lastUpdated)
        if elapsed < 3 {
            return String(localized: "just now")
        } else {
            return String(localized: "\(Int(elapsed))s ago")
        }
    }

    var body: some View {
        HStack {
            Text(reading.label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            HStack(spacing: 4) {
                Text(reading.value)
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.primary)
                if let unit = reading.unit {
                    Text(unit)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "\(reading.label): \(reading.value) \(reading.unit ?? ""), updated \(relativeTime)"))
        .onAppear {
            // Relative time updates via parent polling — just seed the initial value
            now = Date()
        }
        .onChange(of: reading.lastUpdated) { _, newValue in
            now = Date()
        }
    }
}

// MARK: - Preview

#Preview {
    DashboardView(
        store: Store(initialState: DashboardFeature.State()) {
            DashboardFeature()
        } withDependencies: {
            $0.sensorClient = .testValue
            $0.permissionClient = .testValue
        }
    )
}
