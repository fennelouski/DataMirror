import Foundation
import ComposableArchitecture

struct SharedDefaultsClient: Sendable {
    var getScore: @Sendable () -> Int
    var setScore: @Sendable (Int) -> Void
    var getHistory: @Sendable () -> [ScoreSnapshot]
    var setHistory: @Sendable ([ScoreSnapshot]) -> Void
}

private struct UncheckedDefaults: @unchecked Sendable {
    nonisolated(unsafe) let defaults: UserDefaults
}

extension SharedDefaultsClient: DependencyKey {
    nonisolated static let suiteName = "group.com.datamirror"
    nonisolated static let scoreKey = "datamirror.exposurescore"
    nonisolated static let historyKey = "datamirror.scorehistory"

    nonisolated static var liveValue: SharedDefaultsClient {
        let wrapper = UncheckedDefaults(
            defaults: UserDefaults(suiteName: suiteName) ?? .standard
        )
        return SharedDefaultsClient(
            getScore: { wrapper.defaults.integer(forKey: scoreKey) },
            setScore: { wrapper.defaults.set($0, forKey: scoreKey) },
            getHistory: {
                guard let data = wrapper.defaults.data(forKey: historyKey) else { return [] }
                return (try? JSONDecoder().decode([ScoreSnapshot].self, from: data)) ?? []
            },
            setHistory: { snapshots in
                if let data = try? JSONEncoder().encode(snapshots) {
                    wrapper.defaults.set(data, forKey: historyKey)
                }
            }
        )
    }

    nonisolated static var testValue: SharedDefaultsClient {
        SharedDefaultsClient(
            getScore: { 0 },
            setScore: { _ in },
            getHistory: { [] },
            setHistory: { _ in }
        )
    }
}

extension DependencyValues {
    var sharedDefaults: SharedDefaultsClient {
        get { self[SharedDefaultsClient.self] }
        set { self[SharedDefaultsClient.self] = newValue }
    }
}
