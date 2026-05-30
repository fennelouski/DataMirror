//
//  PermissionsFeatureTests.swift
//  DataMirrorTests
//

import ComposableArchitecture
import OrderedCollections
import SwiftUI
import Testing
@testable import DataMirror

@MainActor
struct PermissionsFeatureTests {

    /// Builds the full set of listed permission items, overriding the
    /// location-when-in-use status so we can simulate a status change.
    private func items(locationStatus: PermissionStatus) -> [PermissionItem] {
        PermissionItem.listedItems.map { item in
            var copy = item
            if item.id == .locationWhenInUse {
                copy.status = locationStatus
            }
            return copy
        }
    }

    @Test
    func scenePhaseActiveRefreshesAndSyncsOpenDetail() async {
        let initial = items(locationStatus: .notDetermined)
        guard let locationItem = initial.first(where: { $0.id == .locationWhenInUse }) else {
            Issue.record("Expected a locationWhenInUse permission item")
            return
        }

        var state = PermissionsFeature.State(
            permissions: IdentifiedArrayOf(uniqueElements: initial)
        )
        // Simulate the user drilling into the location detail screen.
        state.path.append(.permissionDetail(PermissionDetailFeature.State(item: locationItem)))

        let store = TestStore(initialState: state) {
            PermissionsFeature()
        } withDependencies: {
            // Returning from Settings, the system now reports location as granted.
            $0.permissionClient.loadAll = { [self] in items(locationStatus: .granted) }
        }

        let refreshed = items(locationStatus: .granted)
        let grantedLocation = refreshed.first { $0.id == .locationWhenInUse }!

        await store.send(.scenePhaseChanged(.active))
        await store.receive(\.permissionsLoaded) {
            $0.permissions = IdentifiedArrayOf(uniqueElements: refreshed)
            let id = $0.path.ids[0]
            guard case .permissionDetail(var detail) = $0.path[id: id] else {
                Issue.record("Expected an open permission detail path element")
                return
            }
            detail.item = grantedLocation
            $0.path[id: id] = .permissionDetail(detail)
        }
    }

    @Test
    func inactiveScenePhaseDoesNotRefresh() async {
        let store = TestStore(
            initialState: PermissionsFeature.State(
                permissions: IdentifiedArrayOf(uniqueElements: items(locationStatus: .granted))
            )
        ) {
            PermissionsFeature()
        }

        // Backgrounding must not trigger a reload (no effect, no state change).
        await store.send(.scenePhaseChanged(.background))
        await store.send(.scenePhaseChanged(.inactive))
    }

    @Test
    func firstAppearLoadsWithSpinnerThenPopulates() async {
        let loaded = items(locationStatus: .granted)
        let store = TestStore(initialState: PermissionsFeature.State()) {
            PermissionsFeature()
        } withDependencies: {
            $0.permissionClient.loadAll = { loaded }
        }

        await store.send(.onAppear) {
            $0.isLoading = true
        }
        await store.receive(\.permissionsLoaded) {
            $0.isLoading = false
            $0.permissions = IdentifiedArrayOf(uniqueElements: loaded)
        }
    }
}
