import ComposableArchitecture
import Foundation

@Reducer
struct AboutFeature {
    @ObservableState
    struct State: Equatable {
        var appVersion: String = Self.currentAppVersion()

        private static func currentAppVersion() -> String {
            let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
            let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
            return "\(version) (\(build))"
        }
    }

    enum Action {}

    var body: some Reducer<State, Action> {
        EmptyReducer()
    }
}
