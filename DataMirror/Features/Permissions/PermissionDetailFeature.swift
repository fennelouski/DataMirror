import ComposableArchitecture

@Reducer
struct PermissionDetailFeature {
    @ObservableState
    struct State: Equatable {
        var item: PermissionItem
        @Presents var grantLevelSheet: GrantLevelInfoFeature.State?
        var showOpenSettingsAlert: Bool = false
        var pendingSettingsReason: String = ""
    }

    enum Action {
        case requestPermissionTapped(PermissionType)
        case openSettingsTapped
        case grantLevelInfoTapped(GrantLevel)
        case grantLevelSheet(PresentationAction<GrantLevelInfoFeature.Action>)
        case openSettingsAlertConfirmed
        case openSettingsAlertCancelled
        case navigateToContacts
        case navigateToPhotos
    }

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case let .grantLevelInfoTapped(level):
                state.grantLevelSheet = GrantLevelInfoFeature.State(
                    level: level,
                    permissionItem: state.item
                )
                return .none
            case .openSettingsTapped:
                state.showOpenSettingsAlert = true
                return .none
            case .openSettingsAlertConfirmed:
                state.showOpenSettingsAlert = false
                return .none
            case .openSettingsAlertCancelled:
                state.showOpenSettingsAlert = false
                return .none
            case .requestPermissionTapped, .navigateToContacts, .navigateToPhotos:
                return .none
            case .grantLevelSheet:
                return .none
            }
        }
        .ifLet(\.$grantLevelSheet, action: \.grantLevelSheet) {
            GrantLevelInfoFeature()
        }
    }
}

@Reducer
struct GrantLevelInfoFeature {
    @ObservableState
    struct State: Equatable {
        let level: GrantLevel
        let permissionItem: PermissionItem
    }
    enum Action {
        case dismissTapped
    }
    var body: some Reducer<State, Action> {
        Reduce { _, action in
            switch action {
            case .dismissTapped: return .none
            }
        }
    }
}
