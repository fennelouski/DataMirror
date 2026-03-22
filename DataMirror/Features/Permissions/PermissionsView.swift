import SwiftUI
import ComposableArchitecture

struct PermissionsView: View {
    @Bindable var store: StoreOf<PermissionsFeature>

    var body: some View {
        NavigationStack(path: $store.scope(state: \.path, action: \.path)) {
            Group {
                if store.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    permissionList
                }
            }
            .navigationTitle(String(localized: "Permissions"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "Open Settings")) {
                        store.send(.openSettingsTapped)
                    }
                    .accessibilityLabel(String(localized: "Open Settings"))
                    .accessibilityHint(String(localized: "Opens iOS Settings to manage permissions"))
                }
            }
            .onAppear { store.send(.onAppear) }
        } destination: { pathStore in
            switch pathStore.case {
            case let .permissionDetail(detailStore):
                PermissionDetailView(store: detailStore)
            case let .contactsDetail(contactsStore):
                ContactsDetailView(store: contactsStore)
            case let .photosGallery(galleryStore):
                PhotosGalleryView(store: galleryStore)
            }
        }
    }

    @ViewBuilder
    private var permissionList: some View {
        List {
            ForEach(PermissionCategory.allCases, id: \.self) { category in
                let items = store.permissions.filter { $0.category == category }
                if !items.isEmpty {
                    Section {
                        ForEach(items) { item in
                            PermissionRow(
                                item: item,
                                onTap: { store.send(.permissionTapped(item.id)) },
                                onRequest: { store.send(.requestPermissionTapped(item.id)) }
                            )
                        }
                    } header: {
                        Label(category.displayName, systemImage: category.sfSymbol)
                    }
                }
            }
        }
    }
}

// MARK: - Permission Row

private struct PermissionRow: View {
    let item: PermissionItem
    let onTap: () -> Void
    let onRequest: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: item.sfSymbol)
                    .font(.title3)
                    .foregroundStyle(statusColor)
                    .frame(width: 32)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(.body)
                        .foregroundStyle(.primary)

                    Text(statusLabel)
                        .font(.caption)
                        .foregroundStyle(statusColor)
                }

                Spacer()

                if item.status == .notDetermined && item.isUserPromptable {
                    Button(String(localized: "Allow")) {
                        onRequest()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.mini)
                    .accessibilityLabel(String(localized: "Request \(item.name) permission"))
                    .accessibilityHint(String(localized: "Requests \(item.name) access from iOS"))
                }

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.name)
        .accessibilityValue(statusLabel)
        .accessibilityHint(String(localized: "Double tap to view permission details"))
    }

    private var statusLabel: String {
        switch item.status {
        case .granted: String(localized: "Granted")
        case .denied: String(localized: "Denied")
        case .notDetermined: String(localized: "Not requested")
        case .restricted: String(localized: "Restricted")
        case .notAvailable: String(localized: "Not available")
        }
    }

    private var statusColor: Color {
        switch item.status {
        case .granted: .green
        case .denied: .red
        case .notDetermined: .orange
        case .restricted: .purple
        case .notAvailable: .gray
        }
    }
}

#Preview {
    PermissionsView(
        store: Store(initialState: PermissionsFeature.State()) {
            PermissionsFeature()
        } withDependencies: {
            $0.permissionClient = .testValue
        }
    )
}
