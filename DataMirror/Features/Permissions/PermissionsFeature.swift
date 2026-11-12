import ComposableArchitecture
import SwiftUI
import UIKit
import os

private nonisolated let logger = Logger(subsystem: "com.datamirror", category: "PermissionsFeature")

@Reducer
struct PermissionsFeature {
    @ObservableState
    struct State: Equatable {
        var permissions: IdentifiedArrayOf<PermissionItem> = []
        var isLoading = false
        var path = StackState<PermissionsPath.State>()
    }

    enum Action {
        case onAppear
        case scenePhaseChanged(ScenePhase)
        case permissionsLoaded([PermissionItem])
        case openSettingsTapped
        case permissionTapped(PermissionType)
        case path(StackActionOf<PermissionsPath>)
    }

    @Dependency(\.permissionClient) var permissionClient

    /// Re-queries every permission's current status from the system.
    /// Reused by `onAppear`, `scenePhaseChanged`, and after an in-app request,
    /// so the list and any open detail view never drift from the real state.
    private func refresh() -> Effect<Action> {
        .run { send in
            let items = await permissionClient.loadAll()
            await send(.permissionsLoaded(items))
        }
    }

    private func openSettings() -> Effect<Action> {
        .run { _ in
            guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
            await MainActor.run { UIApplication.shared.open(url) }
        }
    }

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                // Show the spinner only on the very first load; subsequent
                // re-entries refresh silently in the background.
                if state.permissions.isEmpty {
                    state.isLoading = true
                }
                return refresh()

            case let .scenePhaseChanged(phase):
                // Returning from Settings (or any background trip) backgrounds
                // then re-activates the app — re-query so a permission the user
                // changed outside the app is reflected immediately.
                guard phase == .active else { return .none }
                return refresh()

            case let .permissionsLoaded(items):
                state.isLoading = false
                state.permissions = IdentifiedArrayOf(uniqueElements: items)
                syncPermissionDetailItemsInPath(&state.path, from: state.permissions)
                return .none

            case .openSettingsTapped:
                return openSettings()

            case let .permissionTapped(type_):
                guard let item = state.permissions[id: type_] else { return .none }
                state.path.append(.permissionDetail(PermissionDetailFeature.State(item: item)))
                return .none

            // Settings opens only once the detail screen's "Open Settings?" alert
            // is confirmed — never on the tap that presents the alert.
            case .path(.element(_, action: .permissionDetail(.openSettingsAlertConfirmed))):
                return openSettings()

            case let .path(.element(_, action: .permissionDetail(.requestPermissionTapped(type_)))):
                // iOS shows each prompt once. If this permission has already been
                // answered (a stale screen), don't ask again — just show the truth.
                guard state.permissions[id: type_]?.status == .notDetermined else {
                    return refresh()
                }
                return .run { [permissionClient] send in
                    _ = await permissionClient.request(type_)
                    // One prompt can change several rows (location, photos), so
                    // re-read everything instead of trusting a single result.
                    await send(.permissionsLoaded(await permissionClient.loadAll()))
                }

            case .path(.element(_, action: .permissionDetail(.navigateToContacts))):
                state.path.append(.contactsDetail(ContactsDetailFeature.State()))
                return .none

            case .path(.element(_, action: .permissionDetail(.navigateToPhotos))):
                state.path.append(.photosGallery(PhotosGalleryFeature.State()))
                return .none

            case .path:
                return .none
            }
        }
        .forEach(\.path, action: \.path)
    }
}

@Reducer
enum PermissionsPath {
    case permissionDetail(PermissionDetailFeature)
    case contactsDetail(ContactsDetailFeature)
    case photosGallery(PhotosGalleryFeature)
}

extension PermissionsPath.State: Equatable {}

/// Refreshes the `item` of every open permission-detail screen from the latest
/// loaded permissions, so a `PermissionDetailView` shown while the status changed
/// (in-app request or a Settings round-trip) renders the current state.
private func syncPermissionDetailItemsInPath(
    _ path: inout StackState<PermissionsPath.State>,
    from permissions: IdentifiedArrayOf<PermissionItem>
) {
    for id in path.ids {
        guard let element = path[id: id] else { continue }
        guard case .permissionDetail(var detail) = element else { continue }
        guard let updatedItem = permissions[id: detail.item.id] else { continue }
        guard detail.item != updatedItem else { continue }
        detail.item = updatedItem
        path[id: id] = .permissionDetail(detail)
    }
}
