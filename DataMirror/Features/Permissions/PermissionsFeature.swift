import ComposableArchitecture
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
        case permissionsLoaded([PermissionItem])
        case requestPermissionTapped(PermissionType)
        case permissionRequestCompleted(PermissionType, PermissionStatus)
        case openSettingsTapped
        case permissionTapped(PermissionType)
        case path(StackActionOf<PermissionsPath>)
    }

    @Dependency(\.permissionClient) var permissionClient

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                guard state.permissions.isEmpty else { return .none }
                state.isLoading = true
                return .run { send in
                    let items = await permissionClient.loadAll()
                    await send(.permissionsLoaded(items))
                }

            case let .permissionsLoaded(items):
                state.isLoading = false
                state.permissions = IdentifiedArrayOf(uniqueElements: items)
                return .none

            case let .requestPermissionTapped(type_):
                return .run { [permissionClient] send in
                    let status = await permissionClient.request(type_)
                    await send(.permissionRequestCompleted(type_, status))
                }

            case let .permissionRequestCompleted(type_, status):
                if let idx = state.permissions.firstIndex(where: { $0.id == type_ }) {
                    state.permissions[idx].status = status
                }
                return .none

            case .openSettingsTapped:
                return .run { _ in
                    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                    await UIApplication.shared.open(url)
                }

            case let .permissionTapped(type_):
                guard let item = state.permissions[id: type_] else { return .none }
                state.path.append(.permissionDetail(PermissionDetailFeature.State(item: item)))
                return .none

            case .path(.element(_, action: .permissionDetail(.openSettingsTapped))):
                return .run { _ in
                    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                    await UIApplication.shared.open(url)
                }

            case .path(.element(_, action: .permissionDetail(.openSettingsAlertConfirmed))):
                return .run { _ in
                    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                    await UIApplication.shared.open(url)
                }

            case let .path(.element(_, action: .permissionDetail(.requestPermissionTapped(type_)))):
                return .run { [permissionClient] send in
                    let status = await permissionClient.request(type_)
                    await send(.permissionRequestCompleted(type_, status))
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
