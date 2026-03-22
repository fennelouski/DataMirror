import Foundation
import ComposableArchitecture

struct UserDefaultsClient: Sendable {
    var boolForKey: @Sendable (String) -> Bool
    var setBool: @Sendable (Bool, String) -> Void
    var dataForKey: @Sendable (String) -> Data?
    var setData: @Sendable (Data?, String) -> Void
    var intForKey: @Sendable (String) -> Int
    var setInt: @Sendable (Int, String) -> Void
}

private struct UncheckedDefaults: @unchecked Sendable {
    nonisolated(unsafe) let defaults: UserDefaults
}

extension UserDefaultsClient: DependencyKey {
    nonisolated static var liveValue: UserDefaultsClient {
        let wrapper = UncheckedDefaults(defaults: .standard)
        return UserDefaultsClient(
            boolForKey: { wrapper.defaults.bool(forKey: $0) },
            setBool: { wrapper.defaults.set($0, forKey: $1) },
            dataForKey: { wrapper.defaults.data(forKey: $0) },
            setData: { wrapper.defaults.set($0, forKey: $1) },
            intForKey: { wrapper.defaults.integer(forKey: $0) },
            setInt: { wrapper.defaults.set($0, forKey: $1) }
        )
    }

    nonisolated static var testValue: UserDefaultsClient {
        UserDefaultsClient(
            boolForKey: { _ in false },
            setBool: { _, _ in },
            dataForKey: { _ in nil },
            setData: { _, _ in },
            intForKey: { _ in 0 },
            setInt: { _, _ in }
        )
    }
}

extension DependencyValues {
    var userDefaults: UserDefaultsClient {
        get { self[UserDefaultsClient.self] }
        set { self[UserDefaultsClient.self] = newValue }
    }
}
