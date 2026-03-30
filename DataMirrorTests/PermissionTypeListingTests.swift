//
//  PermissionTypeListingTests.swift
//  DataMirrorTests
//

import Testing
#if os(iOS)
import HealthKit
#endif
@testable import DataMirror

struct PermissionTypeListingTests {

    @Test func listedTypesAreSubsetOfAllCases() {
        let listed = Set(PermissionType.typesListedInPermissionsUI)
        let all = Set(PermissionType.allCases)
        #expect(listed.isSubset(of: all))
    }

    @Test func listedItemsMatchListedTypes() {
        let ids = Set(PermissionItem.listedItems.map(\.id))
        let types = Set(PermissionType.typesListedInPermissionsUI)
        #expect(ids == types)
    }

    @Test func everyListedTypeHasMetadataRow() {
        let ids = Set(PermissionItem.listedItems.map(\.id))
        for type in PermissionType.typesListedInPermissionsUI {
            #expect(ids.contains(type))
        }
    }

    #if os(iOS)
    @Test func iosOmitsStubAndNonRequestablePermissions() {
        let listed = Set(PermissionType.typesListedInPermissionsUI)
        #expect(!listed.contains(.notes))
        #expect(!listed.contains(.siri))
        #expect(!listed.contains(.classKit))
        #expect(!listed.contains(.localNetwork))
        #expect(!listed.contains(.homeKit))
        #expect(!listed.contains(.nearbyInteractions))
    }

    #if targetEnvironment(simulator)
    @Test func simulatorOmitsMotionFitness() {
        #expect(!PermissionType.typesListedInPermissionsUI.contains(.motionFitness))
    }
    #endif

    @Test func healthReadWriteListedWhenHealthDataAvailable() {
        if HKHealthStore.isHealthDataAvailable() {
            #expect(PermissionType.typesListedInPermissionsUI.contains(.healthRead))
            #expect(PermissionType.typesListedInPermissionsUI.contains(.healthWrite))
        }
    }
    #endif
}
