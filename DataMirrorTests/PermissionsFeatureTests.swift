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

    /// State with the location detail screen open, as if the user drilled in.
    private func stateWithLocationDetailOpen(status: PermissionStatus) -> PermissionsFeature.State {
        let initial = items(locationStatus: status)
        var state = PermissionsFeature.State(permissions: IdentifiedArrayOf(uniqueElements: initial))
        state.path.append(.permissionDetail(PermissionDetailFeature.State(
            item: initial.first { $0.id == .locationWhenInUse }!
        )))
        return state
    }

    @Test
    func requestPromptsThenReloadsEveryPermission() async {
        let requested = LockIsolated<[PermissionType]>([])
        let store = TestStore(initialState: stateWithLocationDetailOpen(status: .notDetermined)) {
            PermissionsFeature()
        } withDependencies: {
            $0.permissionClient.request = { type_ in
                requested.withValue { $0.append(type_) }
                return .granted
            }
            $0.permissionClient.loadAll = { [self] in items(locationStatus: .granted) }
        }

        let refreshed = items(locationStatus: .granted)
        let id = store.state.path.ids[0]
        await store.send(.path(.element(id: id, action: .permissionDetail(.requestPermissionTapped(.locationWhenInUse)))))
        await store.receive(\.permissionsLoaded) {
            $0.permissions = IdentifiedArrayOf(uniqueElements: refreshed)
            $0.path[id: id] = .permissionDetail(PermissionDetailFeature.State(
                item: refreshed.first { $0.id == .locationWhenInUse }!
            ))
        }
        #expect(requested.value == [.locationWhenInUse])
    }

    /// The bug this guards against: asking again for a permission iOS will not
    /// prompt for a second time.
    @Test(arguments: [PermissionStatus.denied, .granted, .requested, .restricted, .notAvailable])
    func requestIsNeverSentOnceAnswered(status: PermissionStatus) async {
        let requested = LockIsolated(false)
        let store = TestStore(initialState: stateWithLocationDetailOpen(status: status)) {
            PermissionsFeature()
        } withDependencies: {
            $0.permissionClient.request = { _ in
                requested.setValue(true)
                return .granted
            }
            $0.permissionClient.loadAll = { [self] in items(locationStatus: status) }
        }

        let id = store.state.path.ids[0]
        await store.send(.path(.element(id: id, action: .permissionDetail(.requestPermissionTapped(.locationWhenInUse)))))
        await store.receive(\.permissionsLoaded)
        #expect(!requested.value)
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
