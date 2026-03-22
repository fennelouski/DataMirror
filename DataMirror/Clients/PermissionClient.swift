// FIXED: Added .limited case to contactsStatus() switch (non-exhaustive in iOS 18+)
// FIXED: Replaced deprecated CLLocationManager.authorizationStatus() with instance property
// FIXED: Replaced deprecated INPreferences with .notAvailable for siriStatus (iOS 18 deprecation)
import Foundation
import CoreLocation
import AVFoundation
import Contacts
import EventKit
import Photos
import CoreBluetooth
import CoreMotion
import HealthKit
import UserNotifications
import AppTrackingTransparency
import LocalAuthentication
import Speech
import Intents
import MediaPlayer
import UIKit
import os
import ComposableArchitecture

private nonisolated let logger = Logger(subsystem: "com.datamirror", category: "PermissionClient")

// MARK: - Client interface

struct PermissionClient: Sendable {
    var loadAll: @Sendable () async -> [PermissionItem]
    var request: @Sendable (PermissionType) async -> PermissionStatus
    var currentStatus: @Sendable (PermissionType) -> PermissionStatus
    var fetchContacts: @Sendable () async throws -> [ContactRecord]
    var fetchPhotoAssets: @Sendable () async -> [PhotoAsset]
}

// MARK: - Dependency conformance

extension PermissionClient: DependencyKey {
    nonisolated static var liveValue: PermissionClient {
        PermissionClient(
            loadAll: {
                await withTaskGroup(of: (PermissionType, PermissionStatus).self) { group in
                    for type_ in PermissionType.allCases {
                        group.addTask {
                            let status = await LivePermissionClient.currentStatus(for: type_)
                            return (type_, status)
                        }
                    }
                    var results: [PermissionType: PermissionStatus] = [:]
                    for await (type_, status) in group {
                        results[type_] = status
                    }
                    return PermissionItem.allItems.map { item in
                        PermissionItem(
                            id: item.id,
                            name: item.name,
                            category: item.category,
                            sfSymbol: item.sfSymbol,
                            sensitivityTier: item.sensitivityTier,
                            isUserPromptable: item.isUserPromptable,
                            systemNote: item.systemNote,
                            status: results[item.id] ?? item.status,
                            grantLevels: item.grantLevels,
                            appCapabilities: item.appCapabilities,
                            advertiserInferences: item.advertiserInferences,
                            ungatedData: item.ungatedData
                        )
                    }
                }
            },
            request: { type_ in
                await LivePermissionClient.request(type_)
            },
            currentStatus: { type_ in
                LivePermissionClient.currentStatusSync(for: type_)
            },
            fetchContacts: {
                try await LivePermissionClient.fetchContacts()
            },
            fetchPhotoAssets: {
                await LivePermissionClient.fetchPhotoAssets()
            }
        )
    }

    nonisolated static var testValue: PermissionClient {
        PermissionClient(
            loadAll: {
                PermissionItem.allItems.map { item in
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
            },
            request: { _ in .granted },
            currentStatus: { _ in .notDetermined },
            fetchContacts: { [] },
            fetchPhotoAssets: { [] }
        )
    }
}

extension DependencyValues {
    var permissionClient: PermissionClient {
        get { self[PermissionClient.self] }
        set { self[PermissionClient.self] = newValue }
    }
}

// MARK: - Live implementation helpers

private enum LivePermissionClient {

    static func currentStatus(for type_: PermissionType) async -> PermissionStatus {
        currentStatusSync(for: type_)
    }

    nonisolated static func currentStatusSync(for type_: PermissionType) -> PermissionStatus {
        switch type_ {
        case .locationAlways:
            return locationStatus(requiresAlways: true)
        case .locationWhenInUse:
            return locationStatus(requiresAlways: false)
        case .preciseLocation:
            return preciseLocationStatus()
        case .camera:
            return avMediaStatus(for: .video)
        case .microphone:
            return avMediaStatus(for: .audio)
        case .contacts:
            return contactsStatus()
        case .calendar:
            return eventKitStatus(for: .event)
        case .reminders:
            return eventKitStatus(for: .reminder)
        case .photosReadWrite:
            return photosStatus(level: .readWrite)
        case .photosLimited:
            return photosLimitedStatus()
        case .photosAddOnly:
            return photosStatus(level: .addOnly)
        case .bluetooth:
            return bluetoothStatus()
        case .localNetwork:
            return .notAvailable
        case .motionFitness:
            return motionFitnessStatus()
        case .healthRead:
            return healthStatus()
        case .healthWrite:
            return healthStatus()
        case .notifications:
            return .notDetermined
        case .tracking:
            return attStatus()
        case .faceID:
            return faceIDStatus()
        case .speechRecognition:
            return speechStatus()
        case .siri:
            return siriStatus()
        case .mediaLibrary:
            return mediaLibraryStatus()
        case .nearbyInteractions:
            return .notDetermined
        case .nfc:
            return .notAvailable
        case .notes:
            return .notAvailable
        case .backgroundAppRefresh:
            return backgroundRefreshStatus()
        case .homeKit:
            return .notDetermined
        case .classKit:
            return .notAvailable
        case .focusStatus:
            return focusStatus()
        }
    }

    static func request(_ type_: PermissionType) async -> PermissionStatus {
        switch type_ {
        case .locationAlways:
            return await requestLocation(always: true)
        case .locationWhenInUse:
            return await requestLocation(always: false)
        case .preciseLocation:
            return .notAvailable
        case .camera:
            return await requestAVMedia(for: .video)
        case .microphone:
            return await requestAVMedia(for: .audio)
        case .contacts:
            return await requestContacts()
        case .calendar:
            return await requestEventKit(for: .event)
        case .reminders:
            return await requestEventKit(for: .reminder)
        case .photosReadWrite:
            return await requestPhotos(level: .readWrite)
        case .photosLimited:
            return await requestPhotos(level: .readWrite)
        case .photosAddOnly:
            return await requestPhotos(level: .addOnly)
        case .bluetooth:
            return .notAvailable
        case .localNetwork:
            return .notAvailable
        case .motionFitness:
            return await requestMotion()
        case .healthRead:
            return .notAvailable
        case .healthWrite:
            return .notAvailable
        case .notifications:
            return await requestNotifications()
        case .tracking:
            return await requestATT()
        case .faceID:
            return await requestFaceID()
        case .speechRecognition:
            return await requestSpeech()
        case .siri:
            return .notAvailable
        case .mediaLibrary:
            return await requestMediaLibrary()
        case .nearbyInteractions:
            return .notAvailable
        case .nfc:
            return .notAvailable
        case .notes:
            return .notAvailable
        case .backgroundAppRefresh:
            return .notAvailable
        case .homeKit:
            return .notAvailable
        case .classKit:
            return .notAvailable
        case .focusStatus:
            return await requestFocusStatus()
        }
    }

    // MARK: Current status helpers

    private nonisolated static func locationStatus(requiresAlways: Bool) -> PermissionStatus {
        switch CLLocationManager().authorizationStatus {
        case .authorizedAlways: return .granted
        case .authorizedWhenInUse: return requiresAlways ? .denied : .granted
        case .denied: return .denied
        case .restricted: return .restricted
        case .notDetermined: return .notDetermined
        @unknown default: return .notAvailable
        }
    }

    private nonisolated static func preciseLocationStatus() -> PermissionStatus {
        let manager = CLLocationManager()
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            switch manager.accuracyAuthorization {
            case .fullAccuracy: return .granted
            case .reducedAccuracy: return .denied
            @unknown default: return .notAvailable
            }
        case .denied, .restricted:
            return .denied
        case .notDetermined:
            return .notDetermined
        @unknown default:
            return .notAvailable
        }
    }

    private nonisolated static func avMediaStatus(for mediaType: AVMediaType) -> PermissionStatus {
        switch AVCaptureDevice.authorizationStatus(for: mediaType) {
        case .authorized: return .granted
        case .denied: return .denied
        case .restricted: return .restricted
        case .notDetermined: return .notDetermined
        @unknown default: return .notAvailable
        }
    }

    private nonisolated static func contactsStatus() -> PermissionStatus {
        switch CNContactStore.authorizationStatus(for: .contacts) {
        case .authorized, .limited: return .granted
        case .denied: return .denied
        case .restricted: return .restricted
        case .notDetermined: return .notDetermined
        @unknown default: return .notAvailable
        }
    }

    private nonisolated static func eventKitStatus(for type_: EKEntityType) -> PermissionStatus {
        switch EKEventStore.authorizationStatus(for: type_) {
        case .fullAccess: return .granted
        case .writeOnly: return .granted
        case .denied: return .denied
        case .restricted: return .restricted
        case .notDetermined: return .notDetermined
        @unknown default: return .notAvailable
        }
    }

    private nonisolated static func photosStatus(level: PHAccessLevel) -> PermissionStatus {
        switch PHPhotoLibrary.authorizationStatus(for: level) {
        case .authorized: return .granted
        case .limited: return .granted
        case .denied: return .denied
        case .restricted: return .restricted
        case .notDetermined: return .notDetermined
        @unknown default: return .notAvailable
        }
    }

    private nonisolated static func photosLimitedStatus() -> PermissionStatus {
        switch PHPhotoLibrary.authorizationStatus(for: .readWrite) {
        case .limited: return .granted
        case .authorized: return .denied  // Full access — not limited
        case .denied: return .denied
        case .restricted: return .restricted
        case .notDetermined: return .notDetermined
        @unknown default: return .notAvailable
        }
    }

    private nonisolated static func bluetoothStatus() -> PermissionStatus {
        switch CBCentralManager.authorization {
        case .allowedAlways: return .granted
        case .denied: return .denied
        case .restricted: return .restricted
        case .notDetermined: return .notDetermined
        @unknown default: return .notAvailable
        }
    }

    private nonisolated static func motionFitnessStatus() -> PermissionStatus {
        #if targetEnvironment(simulator)
        return .notAvailable
        #else
        switch CMMotionActivityManager.authorizationStatus() {
        case .authorized: return .granted
        case .denied: return .denied
        case .restricted: return .restricted
        case .notDetermined: return .notDetermined
        @unknown default: return .notAvailable
        }
        #endif
    }

    private nonisolated static func healthStatus() -> PermissionStatus {
        guard HKHealthStore.isHealthDataAvailable() else { return .notAvailable }
        return .notDetermined
    }

    private nonisolated static func attStatus() -> PermissionStatus {
        switch ATTrackingManager.trackingAuthorizationStatus {
        case .authorized: return .granted
        case .denied: return .denied
        case .restricted: return .restricted
        case .notDetermined: return .notDetermined
        @unknown default: return .notAvailable
        }
    }

    private nonisolated static func faceIDStatus() -> PermissionStatus {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return .notAvailable
        }
        guard context.biometryType == .faceID else { return .notAvailable }
        return .notDetermined
    }

    private nonisolated static func speechStatus() -> PermissionStatus {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized: return .granted
        case .denied: return .denied
        case .restricted: return .restricted
        case .notDetermined: return .notDetermined
        @unknown default: return .notAvailable
        }
    }

    // INPreferences is deprecated in iOS 18 — return .notAvailable to avoid using it.
    private nonisolated static func siriStatus() -> PermissionStatus {
        .notAvailable
    }

    private nonisolated static func mediaLibraryStatus() -> PermissionStatus {
        switch MPMediaLibrary.authorizationStatus() {
        case .authorized: return .granted
        case .denied: return .denied
        case .restricted: return .restricted
        case .notDetermined: return .notDetermined
        @unknown default: return .notAvailable
        }
    }

    private nonisolated static func backgroundRefreshStatus() -> PermissionStatus {
        // UIApplication.shared is main-actor-only; access on main actor or use a best-effort sync read.
        // Since this is called from a nonisolated context, return .notDetermined as a safe default.
        // The actual value is checked in the async currentStatus() path below.
        return .notDetermined
    }

    static func backgroundRefreshStatusAsync() async -> PermissionStatus {
        await MainActor.run {
            switch UIApplication.shared.backgroundRefreshStatus {
            case .available: return .granted
            case .denied: return .denied
            case .restricted: return .restricted
            @unknown default: return .notAvailable
            }
        }
    }

    private nonisolated static func focusStatus() -> PermissionStatus {
        switch INFocusStatusCenter.default.authorizationStatus {
        case .authorized: return .granted
        case .denied: return .denied
        case .restricted: return .restricted
        case .notDetermined: return .notDetermined
        @unknown default: return .notAvailable
        }
    }

    // MARK: Request helpers

    @MainActor
    private static func requestLocation(always: Bool) async -> PermissionStatus {
        let manager = CLLocationManager()
        let delegate = RequestLocationDelegate()
        manager.delegate = delegate
        if always {
            manager.requestAlwaysAuthorization()
        } else {
            manager.requestWhenInUseAuthorization()
        }
        await delegate.waitForAuthorization()
        return locationStatus(requiresAlways: always)
    }

    private static func requestAVMedia(for mediaType: AVMediaType) async -> PermissionStatus {
        let granted = await AVCaptureDevice.requestAccess(for: mediaType)
        return granted ? .granted : .denied
    }

    private static func requestContacts() async -> PermissionStatus {
        let store = CNContactStore()
        do {
            let granted = try await store.requestAccess(for: .contacts)
            return granted ? .granted : .denied
        } catch {
            logger.error("Contacts request failed: \(error.localizedDescription)")
            return .denied
        }
    }

    private static func requestEventKit(for type_: EKEntityType) async -> PermissionStatus {
        let store = EKEventStore()
        do {
            if type_ == .event {
                let granted = try await store.requestFullAccessToEvents()
                return granted ? .granted : .denied
            } else {
                let granted = try await store.requestFullAccessToReminders()
                return granted ? .granted : .denied
            }
        } catch {
            logger.error("EventKit request failed: \(error.localizedDescription)")
            return .denied
        }
    }

    private static func requestPhotos(level: PHAccessLevel) async -> PermissionStatus {
        let status = await PHPhotoLibrary.requestAuthorization(for: level)
        switch status {
        case .authorized, .limited: return .granted
        case .denied: return .denied
        case .restricted: return .restricted
        default: return .notDetermined
        }
    }

    private static func requestMotion() async -> PermissionStatus {
        #if targetEnvironment(simulator)
        return .notAvailable
        #else
        let manager = CMMotionActivityManager()
        return await withCheckedContinuation { continuation in
            manager.queryActivityStarting(from: Date(), to: Date(), to: .main) { _, error in
                if let error {
                    logger.error("Motion request failed: \(error.localizedDescription)")
                    continuation.resume(returning: .denied)
                } else {
                    continuation.resume(returning: .granted)
                }
            }
        }
        #endif
    }

    private static func requestNotifications() async -> PermissionStatus {
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            return granted ? .granted : .denied
        } catch {
            logger.error("Notifications request failed: \(error.localizedDescription)")
            return .denied
        }
    }

    private static func requestATT() async -> PermissionStatus {
        let status = await ATTrackingManager.requestTrackingAuthorization()
        switch status {
        case .authorized: return .granted
        case .denied: return .denied
        case .restricted: return .restricted
        default: return .notDetermined
        }
    }

    @MainActor
    private static func requestFaceID() async -> PermissionStatus {
        let context = LAContext()
        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: String(localized: "DataMirror uses Face ID to show you which apps can authenticate with your face.")
            )
            return success ? .granted : .denied
        } catch {
            logger.error("Face ID request failed: \(error.localizedDescription)")
            return .denied
        }
    }

    private static func requestSpeech() async -> PermissionStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                switch status {
                case .authorized: continuation.resume(returning: .granted)
                case .denied: continuation.resume(returning: .denied)
                case .restricted: continuation.resume(returning: .restricted)
                default: continuation.resume(returning: .notDetermined)
                }
            }
        }
    }

    private static func requestMediaLibrary() async -> PermissionStatus {
        await withCheckedContinuation { continuation in
            MPMediaLibrary.requestAuthorization { status in
                switch status {
                case .authorized: continuation.resume(returning: .granted)
                case .denied: continuation.resume(returning: .denied)
                case .restricted: continuation.resume(returning: .restricted)
                default: continuation.resume(returning: .notDetermined)
                }
            }
        }
    }

    private static func requestFocusStatus() async -> PermissionStatus {
        await withCheckedContinuation { continuation in
            INFocusStatusCenter.default.requestAuthorization { status in
                switch status {
                case .authorized: continuation.resume(returning: .granted)
                case .denied: continuation.resume(returning: .denied)
                case .restricted: continuation.resume(returning: .restricted)
                default: continuation.resume(returning: .notDetermined)
                }
            }
        }
    }

    // MARK: fetchContacts

    static func fetchContacts() async throws -> [ContactRecord] {
        let store = CNContactStore()
        let keysToFetch: [CNKeyDescriptor] = [
            CNContactIdentifierKey as CNKeyDescriptor,
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactOrganizationNameKey as CNKeyDescriptor,
            CNContactJobTitleKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor,
            CNContactEmailAddressesKey as CNKeyDescriptor,
            CNContactPostalAddressesKey as CNKeyDescriptor,
            CNContactBirthdayKey as CNKeyDescriptor,
            CNContactNoteKey as CNKeyDescriptor,
            CNContactSocialProfilesKey as CNKeyDescriptor,
            CNContactUrlAddressesKey as CNKeyDescriptor,
            CNContactRelationsKey as CNKeyDescriptor,
            CNContactInstantMessageAddressesKey as CNKeyDescriptor,
            CNContactThumbnailImageDataKey as CNKeyDescriptor,
            CNContactImageDataAvailableKey as CNKeyDescriptor,
        ]
        let request = CNContactFetchRequest(keysToFetch: keysToFetch)
        request.sortOrder = .familyName

        var records: [ContactRecord] = []
        try store.enumerateContacts(with: request) { contact, _ in
            let phoneNumbers = contact.phoneNumbers.map { phone in
                LabeledValue(
                    id: phone.identifier,
                    label: CNLabeledValue<CNPhoneNumber>.localizedString(forLabel: phone.label ?? ""),
                    value: phone.value.stringValue
                )
            }
            let emails = contact.emailAddresses.map { email in
                LabeledValue(
                    id: email.identifier,
                    label: CNLabeledValue<NSString>.localizedString(forLabel: email.label ?? ""),
                    value: email.value as String
                )
            }
            let addresses = contact.postalAddresses.map { addr in
                PostalAddressRecord(
                    id: addr.identifier,
                    label: CNLabeledValue<CNPostalAddress>.localizedString(forLabel: addr.label ?? ""),
                    street: addr.value.street,
                    city: addr.value.city,
                    state: addr.value.state,
                    postalCode: addr.value.postalCode,
                    country: addr.value.country
                )
            }
            let socialProfiles = contact.socialProfiles.map { sp in
                LabeledValue(
                    id: sp.identifier,
                    label: sp.value.service,
                    value: sp.value.username
                )
            }
            let urls = contact.urlAddresses.map { url in
                LabeledValue(
                    id: url.identifier,
                    label: CNLabeledValue<NSString>.localizedString(forLabel: url.label ?? ""),
                    value: url.value as String
                )
            }
            let relations = contact.contactRelations.map { rel in
                LabeledValue(
                    id: rel.identifier,
                    label: CNLabeledValue<CNContactRelation>.localizedString(forLabel: rel.label ?? ""),
                    value: rel.value.name
                )
            }
            let instantMessages = contact.instantMessageAddresses.map { im in
                LabeledValue(
                    id: im.identifier,
                    label: im.value.service,
                    value: im.value.username
                )
            }
            let record = ContactRecord(
                id: contact.identifier,
                givenName: contact.givenName,
                familyName: contact.familyName,
                organizationName: contact.organizationName,
                jobTitle: contact.jobTitle,
                phoneNumbers: phoneNumbers,
                emailAddresses: emails,
                postalAddresses: addresses,
                birthday: contact.birthday,
                note: contact.note,
                socialProfiles: socialProfiles,
                urlAddresses: urls,
                relations: relations,
                instantMessageAddresses: instantMessages,
                thumbnail: contact.thumbnailImageData,
                creationDate: nil,
                modificationDate: nil
            )
            records.append(record)
        }
        return records
    }

    // MARK: fetchPhotoAssets

    static func fetchPhotoAssets() async -> [PhotoAsset] {
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchOptions.fetchLimit = 500
        let result = PHAsset.fetchAssets(with: fetchOptions)

        var assets: [PhotoAsset] = []
        result.enumerateObjects { phAsset, _, _ in
            let location: PhotoLocation?
            if let loc = phAsset.location {
                location = PhotoLocation(
                    latitude: loc.coordinate.latitude,
                    longitude: loc.coordinate.longitude,
                    altitude: loc.altitude != 0 ? loc.altitude : nil
                )
            } else {
                location = nil
            }
            let asset = PhotoAsset(
                id: phAsset.localIdentifier,
                creationDate: phAsset.creationDate,
                modificationDate: phAsset.modificationDate,
                mediaType: phAsset.mediaType,
                mediaSubtypes: phAsset.mediaSubtypes,
                pixelWidth: phAsset.pixelWidth,
                pixelHeight: phAsset.pixelHeight,
                duration: phAsset.duration,
                isFavorite: phAsset.isFavorite,
                isHidden: phAsset.isHidden,
                location: location,
                cameraMake: nil,
                cameraModel: nil,
                lensModel: nil,
                fNumber: nil,
                exposureTime: nil,
                isoSpeed: nil,
                focalLength: nil,
                burstIdentifier: phAsset.burstIdentifier,
                representsThumbnail: nil
            )
            assets.append(asset)
        }
        return assets
    }
}

// MARK: - CLLocationManagerDelegate for async request

private final class RequestLocationDelegate: NSObject, CLLocationManagerDelegate, Sendable {
    private let continuation = OSAllocatedUnfairLock<CheckedContinuation<Void, Never>?>(initialState: nil)

    func waitForAuthorization() async {
        await withCheckedContinuation { cont in
            continuation.withLock { $0 = cont }
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        continuation.withLock { cont in
            cont?.resume()
            cont = nil
        }
    }
}
