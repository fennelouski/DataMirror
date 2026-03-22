import Foundation
import CoreLocation
import os

private nonisolated let logger = Logger(subsystem: "com.datamirror", category: "StructuralInferenceEngine")

// MARK: - InferenceContext

/// Data available for inference computation.
struct InferenceContext: Sendable {
    let contacts: [ContactRecord]?
    let photoAssets: [PhotoAsset]?
    let locationHistory: [SendableLocation]?
    let currentPermissions: [PermissionItem]

    func hasPermission(_ type: PermissionType) -> Bool {
        currentPermissions.contains { $0.id == type && $0.status.isGranted }
    }
}

/// Thread-safe location representation for inference context.
struct SendableLocation: Equatable, Sendable {
    let latitude: Double
    let longitude: Double
    let altitude: Double
    let speed: Double
    let course: Double
    let timestamp: Date
    let horizontalAccuracy: Double
}

// MARK: - InferenceComputable

/// Protocol for individual inference computations.
@MainActor
protocol InferenceComputable {
    static var inferenceType: InferenceType { get }
    static var requiredPermissions: [PermissionType] { get }
    static func compute(from context: InferenceContext) async -> Inference
}

// MARK: - StructuralInferenceEngine

/// Computes slow-changing inferences from available permitted data.
/// Runs once on app foreground and caches results in memory.
final class StructuralInferenceEngine: @unchecked Sendable {
    private let cache = OSAllocatedUnfairLock<[Inference]>(initialState: [])
    private let geocoderCache = OSAllocatedUnfairLock<[String: String]>(initialState: [:])
    private let lastGeocoderCall = OSAllocatedUnfairLock<Date>(initialState: .distantPast)

    nonisolated static let shared = StructuralInferenceEngine()

    @MainActor
    func compute(context: InferenceContext) async -> [Inference] {
        logger.debug("Starting structural inference computation")

        let inferenceTypes: [any InferenceComputable.Type] = [
            HomeAddressInference.self,
            WorkAddressInference.self,
            IncomeBracketInference.self,
            AgeRangeInference.self,
            HouseholdCompositionInference.self,
            RelationshipStatusInference.self,
            CommutePatternInference.self,
            SleepScheduleInference.self,
            PetOwnerInference.self,
        ]

        var results: [Inference] = []
        for inferenceType in inferenceTypes {
            let inference = await inferenceType.compute(from: context)
            results.append(inference)
        }

        let finalResults = results
        cache.withLock { $0 = finalResults }
        logger.debug("Structural inference computation complete: \(finalResults.count) inferences")
        return finalResults
    }

    var cachedResults: [Inference] {
        cache.withLock { $0 }
    }

    // MARK: - Geocoding utilities

    /// Reverse-geocode a coordinate, respecting Apple's rate limit (1 call per 2 seconds).
    nonisolated func reverseGeocode(latitude: Double, longitude: Double) async -> String? {
        let key = String(format: "%.4f,%.4f", latitude, longitude)

        let cached = geocoderCache.withLock { $0[key] }
        if let cached { return cached }

        let timeSinceLast = lastGeocoderCall.withLock { Date().timeIntervalSince($0) }
        if timeSinceLast < 2.0 {
            try? await Task.sleep(nanoseconds: UInt64((2.0 - timeSinceLast) * 1_000_000_000))
        }

        lastGeocoderCall.withLock { $0 = Date() }

        let geocoder = CLGeocoder()
        let location = CLLocation(latitude: latitude, longitude: longitude)
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            if let placemark = placemarks.first {
                let components = [
                    placemark.subThoroughfare,
                    placemark.thoroughfare,
                    placemark.locality,
                    placemark.administrativeArea,
                    placemark.postalCode,
                ].compactMap { $0 }
                let address = components.joined(separator: " ")
                geocoderCache.withLock { $0[key] = address }
                return address
            }
        } catch {
            logger.debug("Geocoder error: \(error.localizedDescription)")
        }
        return nil
    }

    /// Get ZIP code from coordinates.
    nonisolated func zipCode(latitude: Double, longitude: Double) async -> String? {
        let geocoder = CLGeocoder()
        let location = CLLocation(latitude: latitude, longitude: longitude)

        let timeSinceLast = lastGeocoderCall.withLock { Date().timeIntervalSince($0) }
        if timeSinceLast < 2.0 {
            try? await Task.sleep(nanoseconds: UInt64((2.0 - timeSinceLast) * 1_000_000_000))
        }
        lastGeocoderCall.withLock { $0 = Date() }

        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            return placemarks.first?.postalCode
        } catch {
            logger.debug("ZIP geocoder error: \(error.localizedDescription)")
            return nil
        }
    }
}

// MARK: - Clustering utility

/// Simple grid-based coordinate clustering.
enum CoordinateCluster {
    struct Cluster: Sendable {
        let latitude: Double
        let longitude: Double
        let count: Int
        let totalDwellMinutes: Double
    }

    /// Cluster locations into 0.001° grid cells.
    static func cluster(_ locations: [SendableLocation], gridSize: Double = 0.001) -> [Cluster] {
        var grid: [String: (latSum: Double, lonSum: Double, count: Int, minutes: Double)] = [:]

        for loc in locations {
            let gridLat = (loc.latitude / gridSize).rounded(.down) * gridSize
            let gridLon = (loc.longitude / gridSize).rounded(.down) * gridSize
            let key = "\(gridLat),\(gridLon)"

            var entry = grid[key] ?? (0, 0, 0, 0)
            entry.latSum += loc.latitude
            entry.lonSum += loc.longitude
            entry.count += 1
            entry.minutes += 2.0
            grid[key] = entry
        }

        return grid.values.map { entry in
            Cluster(
                latitude: entry.latSum / Double(entry.count),
                longitude: entry.lonSum / Double(entry.count),
                count: entry.count,
                totalDwellMinutes: entry.minutes
            )
        }.sorted { $0.count > $1.count }
    }

    /// Filter locations to specific time-of-day windows.
    static func filter(
        _ locations: [SendableLocation],
        startHour: Int,
        endHour: Int,
        weekdaysOnly: Bool = false,
        weekendsOnly: Bool = false
    ) -> [SendableLocation] {
        let calendar = Calendar.current
        return locations.filter { loc in
            let hour = calendar.component(.hour, from: loc.timestamp)
            let weekday = calendar.component(.weekday, from: loc.timestamp)
            let isWeekday = weekday >= 2 && weekday <= 6

            let hourMatch: Bool
            if startHour <= endHour {
                hourMatch = hour >= startHour && hour < endHour
            } else {
                hourMatch = hour >= startHour || hour < endHour
            }

            if weekdaysOnly { return hourMatch && isWeekday }
            if weekendsOnly { return hourMatch && !isWeekday }
            return hourMatch
        }
    }
}
