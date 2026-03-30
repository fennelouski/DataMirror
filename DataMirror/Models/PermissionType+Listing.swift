import Foundation
import HealthKit
import LocalAuthentication

#if os(iOS)
#if canImport(CoreNFC)
import CoreNFC
#endif
#endif

// MARK: - PermissionType

extension PermissionType {
    /// Whether this permission should appear in the Permissions UI for the current OS and device.
    nonisolated var isListedInPermissionsUI: Bool {
        #if os(iOS)
        return isListedOnIOS
        #elseif os(macOS)
        return isListedOnMacOS
        #elseif os(visionOS)
        return isListedOnVisionOS
        #else
        return false
        #endif
    }

    /// Types shown in the Permissions list, in `CaseIterable` order, filtered by platform rules.
    nonisolated static var typesListedInPermissionsUI: [PermissionType] {
        allCases.filter(\.isListedInPermissionsUI)
    }
}

// MARK: - PermissionItem

extension PermissionItem {
    /// Metadata rows for permissions that are listed on the current platform (see `PermissionType.isListedInPermissionsUI`).
    nonisolated static var listedItems: [PermissionItem] {
        allItems.filter { $0.id.isListedInPermissionsUI }
    }
}

// MARK: - iOS / iPadOS

#if os(iOS)
private extension PermissionType {
    nonisolated var isListedOnIOS: Bool {
        switch self {
        case .notes, .siri, .classKit, .localNetwork, .homeKit, .nearbyInteractions:
            return false
        case .motionFitness:
            #if targetEnvironment(simulator)
            return false
            #else
            return true
            #endif
        case .nfc:
            #if canImport(CoreNFC)
            return NFCNDEFReaderSession.readingAvailable
            #else
            return false
            #endif
        case .faceID:
            return Self.deviceSupportsFaceIDPermissionRow
        case .healthRead, .healthWrite:
            return HKHealthStore.isHealthDataAvailable()
        default:
            return true
        }
    }

    private nonisolated static var deviceSupportsFaceIDPermissionRow: Bool {
        let evaluate: @Sendable () -> Bool = {
            let context = LAContext()
            var error: NSError?
            guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
                return false
            }
            return context.biometryType == .faceID
        }
        if Thread.isMainThread {
            return evaluate()
        }
        return DispatchQueue.main.sync(execute: evaluate)
    }
}
#endif

// MARK: - macOS

#if os(macOS)
private extension PermissionType {
    nonisolated var isListedOnMacOS: Bool {
        switch self {
        case .locationAlways, .locationWhenInUse, .preciseLocation,
             .camera, .microphone, .contacts, .calendar, .reminders,
             .photosReadWrite, .photosLimited, .photosAddOnly,
             .healthRead, .healthWrite,
             .bluetooth, .tracking, .speechRecognition, .notifications,
             .mediaLibrary, .focusStatus:
            switch self {
            case .healthRead, .healthWrite:
                return HKHealthStore.isHealthDataAvailable()
            default:
                return true
            }
        default:
            return false
        }
    }
}
#endif

// MARK: - visionOS

#if os(visionOS)
private extension PermissionType {
    nonisolated var isListedOnVisionOS: Bool {
        switch self {
        case .notes, .siri, .classKit, .localNetwork, .homeKit, .nearbyInteractions,
             .nfc, .faceID, .motionFitness, .backgroundAppRefresh:
            return false
        case .healthRead, .healthWrite:
            return HKHealthStore.isHealthDataAvailable()
        default:
            return true
        }
    }
}
#endif
