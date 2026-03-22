import Foundation
@preconcurrency import CoreMotion
import CoreLocation
import AVFoundation
import UIKit
import os
import ComposableArchitecture

private nonisolated let logger = Logger(subsystem: "com.datamirror", category: "InferenceClient")

/// Provides structural (computed once) and behavioral (live-streaming) inferences.
struct InferenceClient: Sendable {
    var structuralInferences: @Sendable () async -> [Inference]
    var behavioralStream: @Sendable () async -> AsyncStream<[Inference]>
}

extension PermissionStatus {
    nonisolated var isGranted: Bool {
        if case .granted = self { return true }
        return false
    }
}

extension InferenceClient: DependencyKey {
    @MainActor static var liveValue: InferenceClient {
        let permissionClient = PermissionClient.liveValue
        let motionActivityManager = CMMotionActivityManager()

        return InferenceClient(
            structuralInferences: {
                logger.debug("Computing structural inferences")
                let permissions = await permissionClient.loadAll()

                var contacts: [ContactRecord]?
                var photoAssets: [PhotoAsset]?
                var locationHistory: [SendableLocation]?

                if permissions.contains(where: { $0.id == .contacts && $0.status.isGranted }) {
                    contacts = try? await permissionClient.fetchContacts()
                }
                if permissions.contains(where: { ($0.id == .photosReadWrite || $0.id == .photosLimited) && $0.status.isGranted }) {
                    photoAssets = await permissionClient.fetchPhotoAssets()
                }
                if permissions.contains(where: { ($0.id == .locationWhenInUse || $0.id == .locationAlways) && $0.status.isGranted }) {
                    let manager = CLLocationManager()
                    if let location = manager.location {
                        locationHistory = [SendableLocation(
                            latitude: location.coordinate.latitude,
                            longitude: location.coordinate.longitude,
                            altitude: location.altitude,
                            speed: location.speed,
                            course: location.course,
                            timestamp: location.timestamp,
                            horizontalAccuracy: location.horizontalAccuracy
                        )]
                    }
                }

                let context = InferenceContext(
                    contacts: contacts, photoAssets: photoAssets,
                    locationHistory: locationHistory, currentPermissions: permissions
                )

                return await StructuralInferenceEngine.shared.compute(context: context)
            },
            behavioralStream: {
                let permissionClient = PermissionClient.liveValue
                return await BehavioralInferenceEngine.shared.makeStream(
                    sensorProvider: { await makeSensorSnapshot(permissionClient: permissionClient) },
                    activityProvider: { await fetchCurrentActivity(manager: motionActivityManager) }
                )
            }
        )
    }

    nonisolated static var testValue: InferenceClient {
        let now = Date()
        return InferenceClient(
            structuralInferences: {
                [
                    Inference(id: UUID(), category: .location, type: .homeAddress, label: "Home Address (Estimated)", value: .text("123 Main St, Anytown, CA 94000"), confidence: .high, confidenceReason: "Test data", evidence: [Evidence(id: UUID(), permissionType: .locationWhenInUse, description: "42 overnight location samples", rawValue: "37.3346°, -122.0090°", weight: 0.8)], methodology: "Test methodology", databrokerNote: "Test note", permissionsRequired: [.locationWhenInUse], isRealTime: false, lastUpdated: now),
                    Inference(id: UUID(), category: .financial, type: .incomeBracket, label: "Income Bracket (Estimated)", value: .range("$75K", "$100K"), confidence: .medium, confidenceReason: "Test data", evidence: [], methodology: "Test methodology", databrokerNote: "Test note", permissionsRequired: [.locationWhenInUse], isRealTime: false, lastUpdated: now),
                    Inference(id: UUID(), category: .social, type: .householdComposition, label: "Household (Estimated)", value: .list(["Spouse/Partner", "1 child"]), confidence: .high, confidenceReason: "Test data", evidence: [], methodology: "Test methodology", databrokerNote: "Test note", permissionsRequired: [.contacts], isRealTime: false, lastUpdated: now),
                ]
            },
            behavioralStream: {
                AsyncStream { continuation in
                    continuation.yield([
                        Inference(id: UUID(), category: .behavioral, type: .currentActivity, label: "Current Activity (Inferred)", value: .text("Walking"), confidence: .high, confidenceReason: "Test", evidence: [], methodology: "Test", databrokerNote: "Test", permissionsRequired: [.motionFitness], isRealTime: true, lastUpdated: now),
                        Inference(id: UUID(), category: .psychographic, type: .mood, label: "Mood (Inferred)", value: .text("Relaxed"), confidence: .veryLow, confidenceReason: "Test", evidence: [], methodology: "Test", databrokerNote: "Test", permissionsRequired: [.motionFitness], isRealTime: true, lastUpdated: now),
                    ])
                    continuation.finish()
                }
            }
        )
    }
}

extension DependencyValues {
    var inferenceClient: InferenceClient {
        get { self[InferenceClient.self] }
        set { self[InferenceClient.self] = newValue }
    }
}

// MARK: - Helpers

@MainActor
private func makeSensorSnapshot(permissionClient: PermissionClient) async -> BehavioralSensorSnapshot {
    let brightness = UIScreen.main.brightness

    let audioSession = AVAudioSession.sharedInstance()
    let isAudioActive = audioSession.isOtherAudioPlaying
    let permissions = await permissionClient.loadAll()

    return BehavioralSensorSnapshot(
        accelerometerData: nil,
        gyroData: nil,
        screenBrightness: brightness,
        locationSpeed: -1,
        locationCourse: -1,
        isAudioActive: isAudioActive,
        timestamp: Date(),
        currentPermissions: permissions
    )
}

private func fetchCurrentActivity(manager: CMMotionActivityManager) async -> CMMotionActivity? {
    #if targetEnvironment(simulator)
    return nil
    #else
    return await withCheckedContinuation { continuation in
        manager.queryActivityStarting(
            from: Date().addingTimeInterval(-10),
            to: Date(),
            to: .main
        ) { activities, error in
            if let error {
                logger.debug("Activity query error: \(error.localizedDescription)")
                continuation.resume(returning: nil)
            } else {
                continuation.resume(returning: activities?.last)
            }
        }
    }
    #endif
}
