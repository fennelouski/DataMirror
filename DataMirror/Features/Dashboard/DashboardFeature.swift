// FIXED: Removed Action: Equatable (conflicts with @Reducer macro)
// FIXED: Changed body return type to some Reducer<State, Action> (avoids circular reference)
// FIXED: Replaced CancelID enum with string literal (MainActor isolation conflict)
// FIXED: Captured dependency closures before .run (actor isolation)
// FIXED: Added scenePhaseChanged action for score refresh on foreground
import ComposableArchitecture
import SwiftUI
import os

private nonisolated let logger = Logger(subsystem: "com.datamirror", category: "DashboardFeature")

@Reducer
struct DashboardFeature {
    @ObservableState
    struct State: Equatable {
        var sensorGroups: IdentifiedArrayOf<SensorGroup> = []
        var score: ExposureScore = .zero
        var isPolling: Bool = false
        var permissions: IdentifiedArrayOf<PermissionItem> = []
    }

    enum Action {
        case onAppear
        case onDisappear
        case sensorGroupsUpdated([SensorGroup])
        case scoreUpdated(ExposureScore)
        case permissionsLoaded([PermissionItem])
        case scenePhaseChanged(ScenePhase)
    }

    @Dependency(\.sensorClient) var sensorClient
    @Dependency(\.permissionClient) var permissionClient

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                guard !state.isPolling else { return .none }
                state.isPolling = true
                let sensorStream = sensorClient.sensorStream
                let loadAll = permissionClient.loadAll
                return .merge(
                    .run { send in
                        for await groups in sensorStream() {
                            await send(.sensorGroupsUpdated(groups))
                        }
                    }
                    .cancellable(id: "sensorPolling"),
                    .run { send in
                        let items = await loadAll()
                        await send(.permissionsLoaded(items))
                    }
                )

            case .onDisappear:
                state.isPolling = false
                return .cancel(id: "sensorPolling")

            case let .sensorGroupsUpdated(groups):
                state.sensorGroups = IdentifiedArrayOf(uniqueElements: groups)
                return .none

            case let .scoreUpdated(score):
                state.score = score
                return .none

            case let .permissionsLoaded(items):
                state.permissions = IdentifiedArrayOf(uniqueElements: items)
                let score = ExposureScore.compute(from: items)
                state.score = score
                return .none

            case let .scenePhaseChanged(phase):
                guard phase == .active else { return .none }
                let loadAll = permissionClient.loadAll
                return .run { send in
                    let items = await loadAll()
                    await send(.permissionsLoaded(items))
                }
            }
        }
    }
}
