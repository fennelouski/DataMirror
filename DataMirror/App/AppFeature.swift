// FIXED: Removed Action: Equatable (conflicts with @Reducer macro)
// FIXED: Changed body return type to some Reducer<State, Action> (avoids circular reference)
// ADDED: Primer screen, History tab, hasSeenPrimer persistence
import ComposableArchitecture
import Foundation

@Reducer
struct AppFeature {
    @ObservableState
    struct State: Equatable {
        var dashboard = DashboardFeature.State()
        var permissions = PermissionsFeature.State()
        var about = AboutFeature.State()
        var history = HistoryFeature.State()
        var inferred = InferredFeature.State()
        var primer = PrimerFeature.State()
        var selectedTab: Tab = .dashboard
        var hasSeenPrimer: Bool = false
    }

    enum Tab: Equatable, CaseIterable {
        case dashboard
        case permissions
        case inferred
        case history
        case about
    }

    enum Action {
        case tabSelected(Tab)
        case dashboard(DashboardFeature.Action)
        case permissions(PermissionsFeature.Action)
        case about(AboutFeature.Action)
        case history(HistoryFeature.Action)
        case inferred(InferredFeature.Action)
        case primer(PrimerFeature.Action)
        case onAppear
    }

    @Dependency(\.userDefaults) var userDefaults
    @Dependency(\.sharedDefaults) var sharedDefaults

    var body: some Reducer<State, Action> {
        Scope(state: \.dashboard, action: \.dashboard) {
            DashboardFeature()
        }
        Scope(state: \.permissions, action: \.permissions) {
            PermissionsFeature()
        }
        Scope(state: \.about, action: \.about) {
            AboutFeature()
        }
        Scope(state: \.history, action: \.history) {
            HistoryFeature()
        }
        Scope(state: \.inferred, action: \.inferred) {
            InferredFeature()
        }
        Scope(state: \.primer, action: \.primer) {
            PrimerFeature()
        }
        Reduce { state, action in
            switch action {
            case let .tabSelected(tab):
                state.selectedTab = tab
                return .none

            case .onAppear:
                let boolForKey = userDefaults.boolForKey
                state.hasSeenPrimer = boolForKey("hasSeenPrimer")
                return .none

            case .primer(.getStartedTapped):
                state.hasSeenPrimer = true
                return .none

            case let .dashboard(.permissionsLoaded(items)):
                let score = ExposureScore.compute(from: items)
                let setScore = sharedDefaults.setScore
                let getHistory = sharedDefaults.getHistory
                let setHistory = sharedDefaults.setHistory
                return .run { _ in
                    setScore(score.total)
                    // Record history snapshot if needed
                    var history = getHistory()
                    let shouldRecord: Bool
                    if let last = history.last {
                        shouldRecord = Date().timeIntervalSince(last.date) >= 3600
                    } else {
                        shouldRecord = true
                    }
                    if shouldRecord {
                        history.append(ScoreSnapshot(from: score))
                        // Keep max 168 snapshots (7 days * 24 hours)
                        if history.count > 168 {
                            history = Array(history.suffix(168))
                        }
                        setHistory(history)
                    }
                }

            case .dashboard, .permissions, .about, .history, .inferred, .primer:
                return .none
            }
        }
    }
}
