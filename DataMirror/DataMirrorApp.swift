import SwiftUI
import ComposableArchitecture

@main
struct DataMirrorApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    // Created once, with `hasSeenPrimer` read before the first frame so a
    // returning user never sees the primer flash and a new user sees it first.
    static let store = Store(
        initialState: AppFeature.State(
            hasSeenPrimer: UserDefaults.standard.bool(forKey: "hasSeenPrimer")
        )
    ) {
        AppFeature()
    }

    var body: some Scene {
        WindowGroup {
            AppView(store: Self.store)
        }
    }
}
