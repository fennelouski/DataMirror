import SwiftUI
import ComposableArchitecture

struct DashboardView: View {
    @Bindable var store: StoreOf<DashboardFeature>
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ExposureScoreCard(score: store.score, permissions: Array(store.permissions))
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .listRowBackground(Color.clear)

                Section(String(localized: "Sensors")) {
                    if store.sensorGroups.isEmpty {
                        HStack {
                            Spacer()
                            ProgressView(String(localized: "Loading sensors…"))
                                .padding(.vertical, 24)
                            Spacer()
                        }
                    } else {
                        ForEach(store.sensorGroups) { group in
                            Button {
                                store.send(.sensorGroupTapped(group.id))
                            } label: {
                                HStack {
                                    Label(group.name, systemImage: group.sfSymbol)
                                    Spacer()
                                    Text(
                                        String(
                                            localized: "\(group.readings.count) readings",
                                            comment: "Subtitle on dashboard sensor group row; count is inserted."
                                        )
                                    )
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    Image(systemName: "chevron.right")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            .accessibilityHint(String(localized: "Shows live readings for this sensor group"))
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(String(localized: "Live Data"))
            .navigationDestination(item: Binding(
                get: { store.selectedSensorGroupID },
                set: { newValue in
                    if newValue == nil { store.send(.sensorGroupDetailDismissed) }
                }
            )) { id in
                SensorGroupDetailView(
                    groupID: id,
                    sensorGroups: store.sensorGroups
                )
            }
        }
        .onAppear { store.send(.onAppear) }
        .onDisappear { store.send(.onDisappear) }
        .onChange(of: scenePhase) { _, newPhase in
            store.send(.scenePhaseChanged(newPhase))
        }
    }
}

// MARK: - Sensor Group Detail

private struct SensorGroupDetailView: View {
    let groupID: String
    let sensorGroups: IdentifiedArrayOf<SensorGroup>

    private var group: SensorGroup? { sensorGroups[id: groupID] }

    var body: some View {
        Group {
            if let group {
                ScrollView {
                    SensorGroupReadingsContent(group: group)
                        .padding()
                }
                .background(Color(.systemGroupedBackground))
                .navigationTitle(group.name)
            } else {
                ContentUnavailableView(
                    String(localized: "Sensor Unavailable"),
                    systemImage: "sensor.tag.radiowaves.forward.slash",
                    description: Text(String(localized: "This sensor group is no longer available."))
                )
            }
        }
    }
}

// MARK: - Permission Overview Card

private struct ExposureScoreCard: View {
    let score: ExposureScore
    let permissions: [PermissionItem]

    private var ringColor: Color {
        Color.accentColor
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(String(localized: "Permission overview"))
                .font(.headline)
                .accessibilityAddTraits(.isHeader)

            HStack(alignment: .top, spacing: 20) {
                // Circular progress
                ZStack {
                    Circle()
                        .stroke(Color(.systemGray5), lineWidth: 10)
                    Circle()
                        .trim(from: 0, to: CGFloat(score.total) / 100)
                        .stroke(ringColor, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.6), value: score.total)
                    VStack(spacing: 2) {
                        Text("\(score.total)")
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .foregroundStyle(ringColor)
                            .monospacedDigit()
                        Text(String(localized: "of 100"))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 90, height: 90)
                .accessibilityLabel(String(localized: "Permission overview: relative weight \(score.total) out of 100"))
                .accessibilityValue(String(localized: "\(score.total) of 100"))

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

            if !score.topContributors.isEmpty {
                Divider()

                Text(String(localized: "Highest-weight permissions"))
                    .font(.subheadline.bold())
                    .accessibilityAddTraits(.isHeader)

                let totalWeight = score.topContributors.reduce(0) { $0 + $1.1 }

                ForEach(score.topContributors, id: \.0) { type_, weight in
                    if let item = permissions.first(where: { $0.id == type_ }) {
                        HStack {
                            Label(item.name, systemImage: item.sfSymbol)
                                .font(.footnote)
                            Spacer()
                            Text(String(localized: "weight \(weight)"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(String(localized: "\(item.name): weight \(weight)"))
                    }
                }

                Text(String(localized: "These permissions contribute the most to this overview (combined weight \(totalWeight)). You can change them anytime in Settings."))
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

// MARK: - Sensor Group Readings (card body)

private struct SensorGroupReadingsContent: View {
    let group: SensorGroup

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
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
            String(localized: "Go to the Permissions section to request access.")
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
