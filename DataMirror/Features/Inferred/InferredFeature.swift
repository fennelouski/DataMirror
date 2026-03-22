import ComposableArchitecture
import Foundation

@Reducer
struct InferredFeature {
    @ObservableState
    struct State: Equatable {
        var structuralInferences: [Inference] = []
        var behavioralInferences: [Inference] = []
        var isLoading = false
        var showAboutSheet = false
        var selectedInference: Inference?

        var meaningfulInferenceCount: Int {
            (structuralInferences + behavioralInferences).filter { $0.confidence >= .medium }.count
        }

        var groupedStructural: [(InferenceCategory, [Inference])] {
            let groups = Dictionary(grouping: structuralInferences, by: \.category)
            return InferenceCategory.allCases.compactMap { category in
                guard let inferences = groups[category], !inferences.isEmpty else { return nil }
                return (category, inferences)
            }
        }
    }

    enum Action {
        case onAppear
        case structuralInferencesLoaded([Inference])
        case behavioralInferencesUpdated([Inference])
        case inferenceTapped(Inference)
        case inferenceDetailDismissed
        case aboutTapped
        case aboutDismissed
        case scenePhaseChanged(Bool)
    }

    @Dependency(\.inferenceClient) var inferenceClient

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                guard !state.isLoading else { return .none }
                state.isLoading = true
                return .merge(
                    .run { send in
                        let inferences = await inferenceClient.structuralInferences()
                        await send(.structuralInferencesLoaded(inferences))
                    },
                    .run { send in
                        let stream = await inferenceClient.behavioralStream()
                        for await inferences in stream {
                            await send(.behavioralInferencesUpdated(inferences))
                        }
                    }.cancellable(id: "InferredFeature.behavioral")
                )

            case let .structuralInferencesLoaded(inferences):
                state.structuralInferences = inferences
                state.isLoading = false
                return .none

            case let .behavioralInferencesUpdated(inferences):
                state.behavioralInferences = inferences
                return .none

            case let .inferenceTapped(inference):
                state.selectedInference = inference
                return .none

            case .inferenceDetailDismissed:
                state.selectedInference = nil
                return .none

            case .aboutTapped:
                state.showAboutSheet = true
                return .none

            case .aboutDismissed:
                state.showAboutSheet = false
                return .none

            case let .scenePhaseChanged(isActive):
                guard isActive else { return .none }
                return .run { send in
                    let inferences = await inferenceClient.structuralInferences()
                    await send(.structuralInferencesLoaded(inferences))
                }
            }
        }
    }
}
