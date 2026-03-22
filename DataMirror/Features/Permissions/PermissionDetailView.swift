import SwiftUI
import ComposableArchitecture
import MapKit

struct PermissionDetailView: View {
    @Bindable var store: StoreOf<PermissionDetailFeature>

    var body: some View {
        List {
            headerSection
            capabilitiesSection
            advertiserSection
            ungatedDataSection
            grantLevelsSection
            liveDataSection
            actionSection
        }
        .navigationTitle(store.item.name)
        .navigationBarTitleDisplayMode(.large)
        .alert(
            String(localized: "Open Settings?"),
            isPresented: Binding(
                get: { store.showOpenSettingsAlert },
                set: { isPresented in
                    if !isPresented {
                        store.send(.openSettingsAlertCancelled)
                    }
                }
            ),
            actions: {
                Button(String(localized: "Open Settings"), role: .none) {
                    store.send(.openSettingsAlertConfirmed)
                }
                Button(String(localized: "Cancel"), role: .cancel) {
                    store.send(.openSettingsAlertCancelled)
                }
            },
            message: {
                Text(String(localized: "This will open iOS Settings where you can change the \(store.item.name) permission for this app."))
            }
        )
        .sheet(
            item: $store.scope(state: \.grantLevelSheet, action: \.grantLevelSheet)
        ) { sheetStore in
            GrantLevelInfoSheet(store: sheetStore)
        }
    }

    // MARK: - Header Section

    @ViewBuilder
    private var headerSection: some View {
        Section {
            VStack(alignment: .center, spacing: 16) {
                Image(systemName: store.item.sfSymbol)
                    .font(.system(size: 56))
                    .foregroundStyle(tierColor(store.item.sensitivityTier))
                    .accessibilityHidden(true)

                Text(store.item.name)
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)

                statusBadge(store.item.status)

                if let note = store.item.systemNote {
                    DataMirrorPrivacyBanner(text: note)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
    }

    @ViewBuilder
    private func statusBadge(_ status: PermissionStatus) -> some View {
        let (label, color): (String, Color) = switch status {
        case .granted: (String(localized: "Granted"), .green)
        case .denied: (String(localized: "Denied"), .red)
        case .notDetermined: (String(localized: "Not Requested"), .orange)
        case .restricted: (String(localized: "Restricted"), .purple)
        case .notAvailable: (String(localized: "Not Available"), .gray)
        }

        Text(label)
            .font(.caption.bold())
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(color.opacity(0.15), in: Capsule())
            .foregroundStyle(color)
            .accessibilityLabel(String(localized: "Permission status: \(label)"))
    }

    // MARK: - Capabilities

    @ViewBuilder
    private var capabilitiesSection: some View {
        Section(String(localized: "What Apps Can Do")) {
            ForEach(store.item.appCapabilities, id: \.self) { bullet in
                Label(bullet, systemImage: "app.badge.fill")
                    .font(.subheadline)
            }
        }
    }

    // MARK: - Advertiser Inferences

    @ViewBuilder
    private var advertiserSection: some View {
        Section(String(localized: "What Advertisers Can Infer")) {
            ForEach(store.item.advertiserInferences, id: \.self) { bullet in
                Label(bullet, systemImage: "chart.bar.fill")
                    .font(.subheadline)
                    .foregroundStyle(.orange)
            }
        }
    }

    // MARK: - Ungated Data

    @ViewBuilder
    private var ungatedDataSection: some View {
        Section {
            ForEach(store.item.ungatedData, id: \.self) { bullet in
                Label(bullet, systemImage: "lock.open.fill")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text(String(localized: "What You Can't Block"))
        } footer: {
            Text(String(localized: "This data flows to apps regardless of any permission you set."))
        }
    }

    // MARK: - Grant Levels

    @ViewBuilder
    private var grantLevelsSection: some View {
        Section {
            ForEach(store.item.grantLevels) { level in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(level.label)
                            .font(.body)
                        if level.isCurrentSelection {
                            Text(String(localized: "Current selection"))
                                .font(.caption)
                                .foregroundStyle(.green)
                        }
                    }

                    Spacer()

                    if level.isCurrentSelection {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .accessibilityLabel(String(localized: "Currently selected"))
                    }

                    Button {
                        store.send(.grantLevelInfoTapped(level))
                    } label: {
                        Image(systemName: "info.circle")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(String(localized: "Info about \(level.label)"))
                    .accessibilityHint(String(localized: "Double tap to learn what data this level exposes"))
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    if !level.isCurrentSelection {
                        store.send(.openSettingsTapped)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(level.label)
                .accessibilityHint(
                    level.isCurrentSelection
                        ? String(localized: "Currently selected")
                        : String(localized: "Double tap to open Settings and change to this level")
                )
            }
        } header: {
            Text(String(localized: "Permission Levels"))
        } footer: {
            Text(String(localized: "Tap ⓘ on any level to understand exactly what data becomes accessible."))
        }
    }

    // MARK: - Live Data Preview

    @ViewBuilder
    private var liveDataSection: some View {
        if store.item.status == .granted {
            Section(String(localized: "Live Data Preview")) {
                liveDataContent
            }
        }
    }

    @ViewBuilder
    private var liveDataContent: some View {
        switch store.item.id {
        case .locationWhenInUse, .locationAlways, .preciseLocation:
            LocationPreviewRow()

        case .contacts:
            HStack {
                Image(systemName: "person.2.fill")
                    .foregroundStyle(.blue)
                    .accessibilityHidden(true)
                Text(String(localized: "Contact data is accessible to this app."))
                    .font(.subheadline)
                Spacer()
                Button(String(localized: "View All Contacts →")) {
                    store.send(.navigateToContacts)
                }
                .font(.subheadline)
                .accessibilityHint(String(localized: "Opens the full contacts list"))
            }

        case .photosReadWrite, .photosLimited:
            VStack(alignment: .leading, spacing: 8) {
                Text(String(localized: "Photo library is accessible to this app."))
                    .font(.subheadline)
                Button(String(localized: "View Full Gallery →")) {
                    store.send(.navigateToPhotos)
                }
                .font(.subheadline)
                .accessibilityHint(String(localized: "Opens the photos gallery"))
            }

        case .motionFitness:
            IMUVisualizationView()

        case .notifications:
            NotificationPreviewRow()

        default:
            if let summary = store.item.grantLevels.first?.dataAccessSummary {
                Text(summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Action Row

    @ViewBuilder
    private var actionSection: some View {
        Section {
            switch store.item.status {
            case .notDetermined where store.item.isUserPromptable:
                Button {
                    store.send(.requestPermissionTapped(store.item.id))
                } label: {
                    Label(String(localized: "Request Permission"), systemImage: "hand.raised.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityLabel(String(localized: "Request \(store.item.name) permission"))
                .accessibilityHint(String(localized: "Presents the iOS permission prompt"))

            case .denied where store.item.isUserPromptable:
                Button {
                    store.send(.openSettingsTapped)
                } label: {
                    Label(String(localized: "Open Settings"), systemImage: "gear")
                        .frame(maxWidth: .infinity)
                }
                .tint(.secondary)
                .accessibilityLabel(String(localized: "Open iOS Settings for \(store.item.name)"))
                .accessibilityHint(String(localized: "Navigate to iOS Settings to re-enable this permission"))

            case .granted:
                Button(role: .destructive) {
                    store.send(.openSettingsTapped)
                } label: {
                    Label(String(localized: "Revoke in Settings"), systemImage: "xmark.shield.fill")
                        .frame(maxWidth: .infinity)
                }
                .accessibilityLabel(String(localized: "Revoke \(store.item.name) in iOS Settings"))
                .accessibilityHint(String(localized: "Opens Settings to revoke this permission"))

            default:
                EmptyView()
            }
        }
    }

    // MARK: - Helpers

    private func tierColor(_ tier: SensitivityTier) -> Color {
        switch tier {
        case .high: .red
        case .medium: .orange
        case .low: .blue
        }
    }
}

// MARK: - Location Preview Row

private struct LocationPreviewRow: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "Location access is currently granted."))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Notification Preview Row

private struct NotificationPreviewRow: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(String(localized: "Notification permission is granted."))
                .font(.subheadline)
            Text(String(localized: "The app can deliver alerts, sounds, and badge updates."))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Grant Level Info Sheet

struct GrantLevelInfoSheet: View {
    @Bindable var store: StoreOf<GrantLevelInfoFeature>
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(store.level.description)
                        .font(.body)
                }

                Section(String(localized: "What a Developer Can See")) {
                    Text(store.level.dataAccessSummary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Section {
                    LabeledContent(String(localized: "Permission"), value: store.permissionItem.name)
                    LabeledContent(String(localized: "Level"), value: store.level.label)
                    LabeledContent(
                        String(localized: "Sensitivity"),
                        value: store.permissionItem.sensitivityTier.displayName
                    )
                } header: {
                    Text(String(localized: "Details"))
                }
            }
            .navigationTitle(store.level.label)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Done")) {
                        store.send(.dismissTapped)
                        dismiss()
                    }
                    .accessibilityLabel(String(localized: "Close grant level info"))
                }
            }
        }
    }
}

#Preview {
    let item = PermissionItem.allItems.first { $0.id == .locationAlways }
        ?? PermissionItem.allItems[0]
    NavigationStack {
        PermissionDetailView(
            store: Store(
                initialState: PermissionDetailFeature.State(item: item)
            ) {
                PermissionDetailFeature()
            }
        )
    }
}
