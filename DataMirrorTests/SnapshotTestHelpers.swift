//
//  SnapshotTestHelpers.swift
//  DataMirrorTests
//

import SnapshotTesting
import SwiftUI
import UIKit
import XCTest

enum SnapshotTestLayout {
    static let phone = ViewImageConfig.iPhone13(.portrait)
}

enum SnapshotImageStrategy {
    /// Slightly forgiving match for screens that include live `TimeZone.current` / locale snippets in copy.
    static let standard = Snapshotting<UIViewController, UIImage>.image(
        on: SnapshotTestLayout.phone,
        precision: 1,
        perceptualPrecision: 0.98
    )
}

@MainActor
func snapshotRoot<V: View>(_ content: V) -> some View {
    content
        .environment(\.locale, Locale(identifier: "en_US"))
}

@MainActor
func makeHostingController<Content: View>(rootView: Content) -> UIHostingController<Content> {
    let host = UIHostingController(rootView: rootView)
    host.view.overrideUserInterfaceStyle = .light
    return host
}

@MainActor
func settleSnapshot(duration: TimeInterval = 0.35) {
    let exp = XCTestExpectation(description: "snapshot settle")
    DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
        exp.fulfill()
    }
    _ = XCTWaiter.wait(for: [exp], timeout: duration + 1)
}
