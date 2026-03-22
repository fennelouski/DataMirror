import ComposableArchitecture

@Reducer
struct PrimerFeature {
    @ObservableState
    struct State: Equatable {}

    enum Action {
        case getStartedTapped
    }

    @Dependency(\.userDefaults) var userDefaults

    var body: some Reducer<State, Action> {
        Reduce { _, action in
            switch action {
            case .getStartedTapped:
                let setHasSeenPrimer = userDefaults.setBool
                return .run { _ in
                    setHasSeenPrimer(true, "hasSeenPrimer")
                }
            }
        }
    }
}
