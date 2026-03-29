//
//  SnapshotTests.swift
//  DataMirrorTests
//

import ComposableArchitecture
import SnapshotTesting
import SwiftUI
import XCTest

@testable import DataMirror

@MainActor
final class SnapshotTests: XCTestCase {

    /// Mirrors `PermissionClient.testValue.loadAll()` so list snapshots skip async loading.
    private static let snapshotPermissionItems: [PermissionItem] = PermissionItem.allItems.map { item in
        PermissionItem(
            id: item.id,
            name: item.name,
            category: item.category,
            sfSymbol: item.sfSymbol,
            sensitivityTier: item.sensitivityTier,
            isUserPromptable: item.isUserPromptable,
            systemNote: item.systemNote,
            status: item.id == .locationWhenInUse ? .granted : .notDetermined,
            grantLevels: item.grantLevels,
            appCapabilities: item.appCapabilities,
            advertiserInferences: item.advertiserInferences,
            ungatedData: item.ungatedData
        )
    }

    private static let snapshotHistoryDate = Date(timeIntervalSince1970: 1_700_000_000)

    func testDashboardView() {
        let store = Store(initialState: DashboardFeature.State()) {
            DashboardFeature()
        } withDependencies: {
            $0.sensorClient = .testValue
            $0.permissionClient = .testValue
        }
        let host = makeHostingController(
            rootView: snapshotRoot(DashboardView(store: store))
        )
        settleSnapshot()
        assertSnapshot(of: host, as: SnapshotImageStrategy.standard)
    }

    func testPermissionsListView() {
        var state = PermissionsFeature.State()
        state.permissions = IdentifiedArrayOf(uniqueElements: Self.snapshotPermissionItems)
        state.isLoading = false
        let store = Store(initialState: state) {
            PermissionsFeature()
        } withDependencies: {
            $0.permissionClient = .testValue
        }
        let host = makeHostingController(
            rootView: snapshotRoot(PermissionsView(store: store))
        )
        assertSnapshot(of: host, as: SnapshotImageStrategy.standard)
    }

    func testPermissionDetailView() {
        guard let item = Self.snapshotPermissionItems.first(where: { $0.id == .camera }) else {
            XCTFail("Missing camera permission fixture")
            return
        }
        var state = PermissionsFeature.State()
        state.permissions = IdentifiedArrayOf(uniqueElements: Self.snapshotPermissionItems)
        state.isLoading = false
        state.path = StackState([
            .permissionDetail(PermissionDetailFeature.State(item: item)),
        ])
        let store = Store(initialState: state) {
            PermissionsFeature()
        } withDependencies: {
            $0.permissionClient = .testValue
        }
        let host = makeHostingController(
            rootView: snapshotRoot(PermissionsView(store: store))
        )
        assertSnapshot(of: host, as: SnapshotImageStrategy.standard)
    }

    func testInferredView() {
        let store = Store(initialState: InferredFeature.State()) {
            InferredFeature()
        } withDependencies: {
            $0.inferenceClient = .testValue
        }
        let host = makeHostingController(
            rootView: snapshotRoot(InferredView(store: store))
        )
        settleSnapshot()
        assertSnapshot(of: host, as: SnapshotImageStrategy.standard)
    }

    func testHistoryView_withSampleData() {
        let snapshots: [ScoreSnapshot] = [
            ScoreSnapshot(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
                date: Self.snapshotHistoryDate,
                total: 28,
                locationScore: 10,
                identityScore: 5,
                behavioralScore: 8,
                deviceScore: 5
            ),
            ScoreSnapshot(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
                date: Self.snapshotHistoryDate.addingTimeInterval(86_400),
                total: 55,
                locationScore: 20,
                identityScore: 10,
                behavioralScore: 15,
                deviceScore: 10
            ),
        ]
        let store = Store(initialState: HistoryFeature.State(snapshots: snapshots, isLoading: false)) {
            HistoryFeature()
        } withDependencies: {
            $0.sharedDefaults = SharedDefaultsClient(
                getScore: { 55 },
                setScore: { _ in },
                getHistory: { snapshots },
                setHistory: { _ in }
            )
            $0.date = .constant(Self.snapshotHistoryDate)
        }
        let host = makeHostingController(
            rootView: snapshotRoot(HistoryView(store: store))
        )
        assertSnapshot(of: host, as: SnapshotImageStrategy.standard)
    }

    func testHistoryView_empty() {
        let store = Store(initialState: HistoryFeature.State(snapshots: [], isLoading: false)) {
            HistoryFeature()
        } withDependencies: {
            $0.sharedDefaults = .testValue
            $0.date = .constant(Self.snapshotHistoryDate)
        }
        let host = makeHostingController(
            rootView: snapshotRoot(HistoryView(store: store))
        )
        assertSnapshot(of: host, as: SnapshotImageStrategy.standard)
    }

    func testAboutView() {
        let store = Store(initialState: AboutFeature.State()) {
            AboutFeature()
        }
        let host = makeHostingController(
            rootView: snapshotRoot(AboutView(store: store))
        )
        assertSnapshot(of: host, as: SnapshotImageStrategy.standard)
    }

    func testPrimerView() {
        let store = Store(initialState: PrimerFeature.State()) {
            PrimerFeature()
        } withDependencies: {
            $0.userDefaults = .testValue
        }
        let host = makeHostingController(
            rootView: snapshotRoot(PrimerView(store: store))
        )
        assertSnapshot(of: host, as: SnapshotImageStrategy.standard)
    }
}
