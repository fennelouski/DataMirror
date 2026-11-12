import SwiftUI
import UIKit

/// Routes an external display (AirPlay, HDMI) to `ExternalDisplayView`.
/// Without this, iOS mirrors the phone: a portrait picture with black bars.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        if connectingSceneSession.role == .windowExternalDisplayNonInteractive {
            configuration.delegateClass = ExternalDisplaySceneDelegate.self
        }
        return configuration
    }
}

final class ExternalDisplaySceneDelegate: NSObject, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: windowScene)
        // Same store as the phone, so the two screens cannot disagree.
        window.rootViewController = UIHostingController(
            rootView: ExternalDisplayView(store: DataMirrorApp.store)
        )
        window.isHidden = false
        self.window = window
    }
}
