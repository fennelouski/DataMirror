import Foundation
import CoreMotion
import AVFoundation
import UIKit
import os

private nonisolated let logger = Logger(subsystem: "com.datamirror", category: "BehavioralInferenceEngine")

// MARK: - BehavioralSensorSnapshot

/// A snapshot of current sensor state for behavioral inference.
struct BehavioralSensorSnapshot: Sendable {
    let accelerometerData: (x: Double, y: Double, z: Double)?
    let gyroData: (x: Double, y: Double, z: Double)?
    let screenBrightness: Double
    let locationSpeed: Double
    let locationCourse: Double
    let isAudioActive: Bool
    let timestamp: Date
    let currentPermissions: [PermissionItem]

    func hasPermission(_ type: PermissionType) -> Bool {
        currentPermissions.contains { $0.id == type && $0.status.isGranted }
    }
}

// MARK: - BehavioralInferenceEngine

/// Produces a live stream of behavioral inferences, updating every 10 seconds.
final class BehavioralInferenceEngine: @unchecked Sendable {
    nonisolated static let shared = BehavioralInferenceEngine()

    private let brightnessTransitions = OSAllocatedUnfairLock<[Date]>(initialState: [])
    private let previousBrightness = OSAllocatedUnfairLock<Double>(initialState: 0)

    func makeStream(
        sensorProvider: @escaping @Sendable () async -> BehavioralSensorSnapshot,
        activityProvider: @escaping @Sendable () async -> CMMotionActivity?
    ) -> AsyncStream<[Inference]> {
        AsyncStream { continuation in
            let task = Task { [weak self] in
                while !Task.isCancelled {
                    guard let self else { break }
                    let snapshot = await sensorProvider()
                    let activity = await activityProvider()

                    self.trackBrightnessTransition(snapshot.screenBrightness)

                    var inferences: [Inference] = []
                    inferences.append(CurrentActivityInference.compute(activity: activity, snapshot: snapshot))
                    inferences.append(DrivingInference.compute(activity: activity, snapshot: snapshot))
                    inferences.append(ExercisePatternInference.computeBehavioral(activity: activity, snapshot: snapshot))
                    inferences.append(WorkingInference.compute(activity: activity, snapshot: snapshot))
                    let pickups = self.recentPickupCount()
                    inferences.append(StressInference.compute(snapshot: snapshot, devicePickups: pickups))
                    inferences.append(MoodInference.compute(activity: activity, snapshot: snapshot))

                    continuation.yield(inferences)
                    try? await Task.sleep(nanoseconds: 10_000_000_000)
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func trackBrightnessTransition(_ brightness: Double) {
        let prev = previousBrightness.withLock { $0 }
        if prev == 0 && brightness > 0 {
            brightnessTransitions.withLock { transitions in
                transitions.append(Date())
                let cutoff = Date().addingTimeInterval(-3600)
                transitions.removeAll { $0 < cutoff }
            }
        }
        previousBrightness.withLock { $0 = brightness }
    }

    private func recentPickupCount() -> Int {
        brightnessTransitions.withLock { $0.count }
    }
}
