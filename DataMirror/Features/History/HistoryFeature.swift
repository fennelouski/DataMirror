import ComposableArchitecture
import Foundation
import SwiftUI

@Reducer
struct HistoryFeature {
    @ObservableState
    struct State: Equatable {
        var snapshots: [ScoreSnapshot] = []
        var isLoading = true
    }

    enum Action {
        case onAppear
        case snapshotsLoaded([ScoreSnapshot])
        case scenePhaseChanged(ScenePhase)
    }

    @Dependency(\.sharedDefaults) var sharedDefaults
    @Dependency(\.date.now) var now

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                let getHistory = sharedDefaults.getHistory
                return .run { send in
                    let history = getHistory()
                    await send(.snapshotsLoaded(history))
                }

            case let .snapshotsLoaded(snapshots):
                state.snapshots = snapshots.sorted { $0.date < $1.date }
                state.isLoading = false
                return .none

            case let .scenePhaseChanged(phase):
                guard phase == .active else { return .none }
                let getHistory = sharedDefaults.getHistory
                return .run { send in
                    let history = getHistory()
                    await send(.snapshotsLoaded(history))
                }
            }
        }
    }
}
