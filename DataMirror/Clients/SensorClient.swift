import Foundation
import Darwin
import CoreMotion
import AVFoundation
import CoreLocation
import Network
import UIKit
import os
import ComposableArchitecture

private nonisolated let logger = Logger(
    subsystem: "com.datamirror",
    category: "SensorClient"
)

// MARK: - IP Geolocation

private struct IPGeoResult: Sendable {
    let publicIP: String
    let city: String
    let region: String
    let country: String
    let isp: String
    let timezone: String  // e.g. "America/New_York" — differs from device TZ when on VPN
}


// MARK: - Client interface

struct SensorClient: Sendable {
    var sensorStream: @Sendable () -> AsyncStream<[SensorGroup]>
    var currentScore: @Sendable () -> ExposureScore
}

// MARK: - Dependency conformance

extension SensorClient: DependencyKey {
    @MainActor static var liveValue: SensorClient {
        LiveSensorClient.shared
            .makeClient()
    }
    
    nonisolated static var testValue: SensorClient {
        SensorClient(
            sensorStream: {
                AsyncStream { continuation in
                    continuation
                        .yield(
                            SensorGroup.mockGroups
                        )
                    continuation
                        .finish()
                }
            },
            currentScore: {
                ExposureScore.zero
            }
        )
    }
}

extension DependencyValues {
    var sensorClient: SensorClient {
        get {
            self[SensorClient.self]
        }
        set {
            self[SensorClient.self] = newValue
        }
    }
}

// MARK: - Live implementation

private final class LiveSensorClient: @unchecked Sendable {
    static let shared = LiveSensorClient()
    
    private let motionManager = CMMotionManager()
    private let locationManager = CLLocationManager()
    private let locationDelegate = LocationDelegate()
    /// Whether `startUpdatingLocation()` has been issued. Mutated only from the
    /// @MainActor sensor build/teardown path, so plain storage is safe here.
    private var isUpdatingLocation = false
    private let networkMonitor = NWPathMonitor()
    private let networkQueue = DispatchQueue(
        label: "com.datamirror.network"
    )
    
    private let _currentPath = OSAllocatedUnfairLock<NWPath?>(
        initialState: nil
    )
    private var currentPath: NWPath? {
        _currentPath
            .withLock {
                $0
            }
    }
    
    private let _ipGeoCache = OSAllocatedUnfairLock<IPGeoResult?>(
        initialState: nil
    )
    private var ipGeoCache: IPGeoResult? {
        _ipGeoCache.withLock {
            $0
        }
    }
    
    private init() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            let previous = self._currentPath.withLock { existing -> NWPath? in
                let old = existing
                existing = path
                return old
            }
            // When the network identity changes (interface set, type, or
            // reachability), the cached public IP / geolocation is stale — clear
            // it and re-fetch so the Network group reflects the new network
            // (e.g. after a VPN toggle or Wi-Fi↔cellular switch).
            if Self.networkSignature(previous) != Self.networkSignature(path) {
                self._ipGeoCache.withLock { $0 = nil }
                Task { await self.fetchIPGeo() }
            }
        }
        networkMonitor
            .start(
                queue: networkQueue
            )
        locationManager.delegate = locationDelegate
    }

    /// A stable fingerprint of the current network so we can tell when the device
    /// has actually moved to a different network (vs. routine path callbacks).
    private static func networkSignature(_ path: NWPath?) -> String {
        guard let path else { return "none" }
        let interfaces = path.availableInterfaces
            .map { "\($0.type):\($0.name)" }
            .sorted()
            .joined(separator: ",")
        return "\(path.status)|expensive:\(path.isExpensive)|\(interfaces)"
    }
    
    func makeClient() -> SensorClient {
        SensorClient(
            sensorStream: { [weak self] in
                guard let self else {
                    return AsyncStream {
                        $0.finish()
                    }
                }
                return AsyncStream { continuation in
                    Task {
                        await self.startPolling(
                            continuation: continuation
                        )
                    }
                }
            },
            currentScore: {
                ExposureScore.zero
            }
        )
    }
    
    @MainActor
    private func startPolling(
        continuation: AsyncStream<[SensorGroup]>.Continuation
    ) async {
#if !targetEnvironment(simulator)
        if motionManager.isAccelerometerAvailable {
            motionManager.accelerometerUpdateInterval = 0.5
            motionManager
                .startAccelerometerUpdates()
        }
        if motionManager.isGyroAvailable {
            motionManager.gyroUpdateInterval = 0.5
            motionManager
                .startGyroUpdates()
        }
#endif
        
        // Fetch IP geolocation once per session in the background
        Task {
            await self.fetchIPGeo()
        }
        
        while !Task.isCancelled {
            let groups = buildGroups()
            continuation
                .yield(
                    groups
                )
            try? await Task
                .sleep(
                    nanoseconds: 2_000_000_000
                )
        }
        
#if !targetEnvironment(simulator)
        motionManager
            .stopAccelerometerUpdates()
        motionManager
            .stopGyroUpdates()
#endif
        if isUpdatingLocation {
            locationManager.stopUpdatingLocation()
            isUpdatingLocation = false
        }
        continuation
            .finish()
    }
    
    @MainActor
    private func buildGroups() -> [SensorGroup] {
        let now = Date()
        var groups: [SensorGroup] = []
        
        // Device Identity
        groups
            .append(
                buildDeviceGroup(
                    now: now
                )
            )
        
        // Network
        groups
            .append(
                buildNetworkGroup(
                    now: now
                )
            )
        
        // Motion & Orientation
        groups
            .append(
                buildMotionGroup(
                    now: now
                )
            )
        
        // Environment
        groups
            .append(
                buildEnvironmentGroup(
                    now: now
                )
            )
        
        // Location
        groups
            .append(
                buildLocationGroup(
                    now: now
                )
            )
        
        return groups
    }
    
    @MainActor
    private func buildDeviceGroup(
        now: Date
    ) -> SensorGroup {
        let device = UIDevice.current
        device.isBatteryMonitoringEnabled = true
        
        let batteryState: String
        switch device.batteryState {
        case .charging: batteryState = String(
            localized: "Charging"
        )
        case .full: batteryState = String(
            localized: "Full"
        )
        case .unplugged: batteryState = String(
            localized: "Unplugged"
        )
        default: batteryState = String(
            localized: "Unknown"
        )
        }
        
        let batteryLevel = device.batteryLevel >= 0
        ? String(
            format: "%.0f%%",
            device.batteryLevel * 100
        )
        : String(
            localized: "Unknown"
        )
        
        return SensorGroup(
            id: "device",
            name: String(
                localized: "Device Identity"
            ),
            sfSymbol: "iphone",
            readings: [
                SensorReading(
                    id: "device.model",
                    label: String(
                        localized: "Model"
                    ),
                    value: device.model,
                    unit: nil,
                    lastUpdated: now,
                    requiresPermission: false,
                    permissionStatus: .granted
                ),
                SensorReading(
                    id: "device.system",
                    label: String(
                        localized: "iOS Version"
                    ),
                    value: "\(device.systemName) \(device.systemVersion)",
                    unit: nil,
                    lastUpdated: now,
                    requiresPermission: false,
                    permissionStatus: .granted
                ),
                SensorReading(
                    id: "device.locale",
                    label: String(
                        localized: "Locale"
                    ),
                    value: Locale.current.identifier,
                    unit: nil,
                    lastUpdated: now,
                    requiresPermission: false,
                    permissionStatus: .granted
                ),
                SensorReading(
                    id: "device.region",
                    label: String(
                        localized: "Region"
                    ),
                    value: Locale.current.region?.identifier ?? String(
                        localized: "Unknown"
                    ),
                    unit: nil,
                    lastUpdated: now,
                    requiresPermission: false,
                    permissionStatus: .granted
                ),
                SensorReading(
                    id: "device.timezone",
                    label: String(
                        localized: "Timezone"
                    ),
                    value: TimeZone.current.identifier,
                    unit: nil,
                    lastUpdated: now,
                    requiresPermission: false,
                    permissionStatus: .granted
                ),
                SensorReading(
                    id: "device.battery.level",
                    label: String(
                        localized: "Battery Level"
                    ),
                    value: batteryLevel,
                    unit: nil,
                    lastUpdated: now,
                    requiresPermission: false,
                    permissionStatus: .granted
                ),
                SensorReading(
                    id: "device.battery.state",
                    label: String(
                        localized: "Charging State"
                    ),
                    value: batteryState,
                    unit: nil,
                    lastUpdated: now,
                    requiresPermission: false,
                    permissionStatus: .granted
                ),
                SensorReading(
                    id: "device.lowpower",
                    label: String(
                        localized: "Low Power Mode"
                    ),
                    value: ProcessInfo.processInfo.isLowPowerModeEnabled ? String(
                        localized: "On"
                    ) : String(
                        localized: "Off"
                    ),
                    unit: nil,
                    lastUpdated: now,
                    requiresPermission: false,
                    permissionStatus: .granted
                ),
            ]
        )
    }
    
    @MainActor
    private func buildNetworkGroup(
        now: Date
    ) -> SensorGroup {
        let path = currentPath
        let connectionType: String
        if let path {
            if path
                .usesInterfaceType(
                    .wifi
                ) {
                connectionType = String(
                    localized: "Wi-Fi"
                )
            } else if path.usesInterfaceType(
                .cellular
            ) {
                connectionType = String(
                    localized: "Cellular"
                )
            } else if path.status == .satisfied {
                connectionType = String(
                    localized: "Other"
                )
            } else {
                connectionType = String(
                    localized: "None"
                )
            }
        } else {
            connectionType = String(
                localized: "Unknown"
            )
        }
        
        let carrierName = carrierNameReading()
        let localIP = localIPAddress() ?? String(
            localized: "Unknown"
        )
        let vpnActive = isVPNActive()
        let geo = ipGeoCache
        
        var readings: [SensorReading] = [
            SensorReading(
                id: "network.connection",
                label: String(
                    localized: "Connection"
                ),
                value: connectionType,
                unit: nil,
                lastUpdated: now,
                requiresPermission: false,
                permissionStatus: .granted
            ),
            SensorReading(
                id: "network.carrier",
                label: String(
                    localized: "Carrier"
                ),
                value: carrierName,
                unit: nil,
                lastUpdated: now,
                requiresPermission: false,
                permissionStatus: .granted
            ),
            SensorReading(
                id: "network.localip",
                label: String(
                    localized: "Local IP"
                ),
                value: localIP,
                unit: nil,
                lastUpdated: now,
                requiresPermission: false,
                permissionStatus: .granted
            ),
            SensorReading(
                id: "network.vpn",
                label: String(
                    localized: "VPN Active"
                ),
                value: vpnActive ? String(
                    localized: "Yes"
                ) : String(
                    localized: "No"
                ),
                unit: nil,
                lastUpdated: now,
                requiresPermission: false,
                permissionStatus: .granted
            ),
        ]
        
        if let geo {
            let locationParts = [
                geo.city,
                geo.region,
                geo.country
            ].filter {
                !$0.isEmpty
            }
            let locationStr = locationParts.joined(
                separator: ", "
            )
            
            readings
                .append(
                    SensorReading(
                        id: "network.publicip",
                        label: String(
                            localized: "Public IP"
                        ),
                        value: geo.publicIP,
                        unit: nil,
                        lastUpdated: now,
                        requiresPermission: false,
                        permissionStatus: .granted
                    )
                )
            readings
                .append(
                    SensorReading(
                        id: "network.iplocation",
                        label: vpnActive ? String(
                            localized: "VPN Exit Location"
                        ) : String(
                            localized: "IP Location"
                        ),
                        value: locationStr.isEmpty ? String(
                            localized: "Unknown"
                        ) : locationStr,
                        unit: nil,
                        lastUpdated: now,
                        requiresPermission: false,
                        permissionStatus: .granted
                    )
                )
            readings
                .append(
                    SensorReading(
                        id: "network.isp",
                        label: vpnActive ? String(
                            localized: "VPN Provider"
                        ) : String(
                            localized: "ISP"
                        ),
                        value: geo.isp,
                        unit: nil,
                        lastUpdated: now,
                        requiresPermission: false,
                        permissionStatus: .granted
                    )
                )
            
            if vpnActive {
                readings
                    .append(
                        SensorReading(
                            id: "network.vpn.geoaccess",
                            label: String(
                                localized: "Location via IP"
                            ),
                            value: String(
                                localized: "VPN exit node — not your real location"
                            ),
                            unit: nil,
                            lastUpdated: now,
                            requiresPermission: false,
                            permissionStatus: .granted
                        )
                    )
                readings
                    .append(
                        SensorReading(
                            id: "network.vpn.ispaccess",
                            label: String(
                                localized: "ISP via IP"
                            ),
                            value: String(
                                localized: "VPN provider visible — real ISP hidden"
                            ),
                            unit: nil,
                            lastUpdated: now,
                            requiresPermission: false,
                            permissionStatus: .granted
                        )
                    )
                readings
                    .append(
                        SensorReading(
                            id: "network.vpn.remaining",
                            label: String(
                                localized: "Still trackable via"
                            ),
                            value: String(
                                localized: "Device fingerprint, account data, behavior"
                            ),
                            unit: nil,
                            lastUpdated: now,
                            requiresPermission: false,
                            permissionStatus: .granted
                        )
                    )
                readings
                    .append(
                        SensorReading(
                            id: "network.vpn.signal",
                            label: String(
                                localized: "VPN signals"
                            ),
                            value: String(
                                localized: "Privacy-conscious, geo-restricted access, or corporate network"
                            ),
                            unit: nil,
                            lastUpdated: now,
                            requiresPermission: false,
                            permissionStatus: .granted
                        )
                    )
            } else {
                readings
                    .append(
                        SensorReading(
                            id: "network.ipgeo.note",
                            label: String(
                                localized: "No permission needed"
                            ),
                            value: String(
                                localized: "Any server can infer ~city from your IP"
                            ),
                            unit: nil,
                            lastUpdated: now,
                            requiresPermission: false,
                            permissionStatus: .granted
                        )
                    )
            }
        } else {
            readings
                .append(
                    SensorReading(
                        id: "network.iplocation",
                        label: String(
                            localized: "IP Location"
                        ),
                        value: String(
                            localized: "Loading…"
                        ),
                        unit: nil,
                        lastUpdated: now,
                        requiresPermission: false,
                        permissionStatus: .granted
                    )
                )
        }
        
        // MARK: Timezone signal alignment
        // Device timezone comes from iOS system settings — VPNs cannot intercept it.
        // Comparing it against the IP geo timezone exposes VPN usage or spoofing.
        let deviceTZId = TimeZone.current.identifier
        readings
            .append(
                SensorReading(
                    id: "network.tz.device",
                    label: String(
                        localized: "Device Timezone"
                    ),
                    value: deviceTZId,
                    unit: nil,
                    lastUpdated: now,
                    requiresPermission: false,
                    permissionStatus: .granted
                )
            )
        if let geo, !geo.timezone.isEmpty {
            let ipTZ = geo.timezone
            let match = deviceTZId == ipTZ
            readings
                .append(
                    SensorReading(
                        id: "network.tz.ip",
                        label: String(
                            localized: "IP Geo Timezone"
                        ),
                        value: ipTZ,
                        unit: nil,
                        lastUpdated: now,
                        requiresPermission: false,
                        permissionStatus: .granted
                    )
                )
            readings
                .append(
                    SensorReading(
                        id: "network.tz.match",
                        label: String(
                            localized: "Timezone Match"
                        ),
                        value: match
                        ? String(
                            localized: "Yes — timezone consistent with IP region"
                        )
                        : String(
                            localized: "No — device timezone differs from IP region"
                        ),
                        unit: nil,
                        lastUpdated: now,
                        requiresPermission: false,
                        permissionStatus: .granted
                    )
                )
            if !match {
                let explanation = vpnActive
                ? String(
                    localized: "Timezone bypasses VPN — reveals your real region to anyone who asks"
                )
                : String(
                    localized: "Travel, recent move, or manually set timezone"
                )
                readings
                    .append(
                        SensorReading(
                            id: "network.tz.mismatch.why",
                            label: String(
                                localized: "Mismatch means"
                            ),
                            value: explanation,
                            unit: nil,
                            lastUpdated: now,
                            requiresPermission: false,
                            permissionStatus: .granted
                        )
                    )
            }
        } else if geo == nil {
            readings
                .append(
                    SensorReading(
                        id: "network.tz.note",
                        label: String(
                            localized: "Timezone signal"
                        ),
                        value: String(
                            localized: "Not routed through VPN — always reveals real region"
                        ),
                        unit: nil,
                        lastUpdated: now,
                        requiresPermission: false,
                        permissionStatus: .granted
                    )
                )
        }
        
        return SensorGroup(
            id: "network",
            name: String(
                localized: "Network"
            ),
            sfSymbol: vpnActive ? "shield.fill" : "wifi",
            readings: readings
        )
    }
    
    private func carrierNameReading() -> String {
        // CTCarrier.carrierName and serviceSubscriberCellularProviders were deprecated
        // in iOS 16 with no replacement — Apple removed direct carrier access for privacy.
        // The APIs return "--" on modern OS versions, so we report unavailable.
        return String(
            localized: "Unavailable"
        )
    }
    
    // MARK: - IP Geolocation
    
    nonisolated private func fetchIPGeo() async {
        guard _ipGeoCache
            .withLock(
                {
                    $0
                }) == nil else {
            return
        }
        do {
            let url = URL(
                string: "https://ipapi.co/json/"
            )!
            let (
                data,
                _
            ) = try await URLSession.shared.data(
                from: url
            )
            guard let json = try JSONSerialization.jsonObject(
                with: data
            ) as? [String: Any] else {
                return
            }
            let result = IPGeoResult(
                publicIP: json["ip"] as? String ?? "",
                city: json["city"] as? String ?? "",
                region: json["region"] as? String ?? "",
                country: json["country_name"] as? String ?? "",
                isp: json["org"] as? String ?? "",
                timezone: json["timezone"] as? String ?? ""
            )
            _ipGeoCache
                .withLock {
                    $0 = result
                }
        } catch {
            logger
                .warning(
                    "IP geolocation fetch failed: \(error.localizedDescription)"
                )
        }
    }
    
    // MARK: - VPN Detection
    
    /// Detects active VPN by checking for tunnel network interfaces (utun, ipsec).
    /// These are created by WireGuard, OpenVPN, IKEv2, L2TP, and iOS system VPNs.
    nonisolated private func isVPNActive() -> Bool {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(
            &ifaddr
        ) == 0 else {
            return false
        }
        defer {
            freeifaddrs(
                ifaddr
            )
        }
        var ptr = ifaddr
        while let current = ptr {
            let name = String(
                cString: current.pointee.ifa_name
            )
            if name
                .hasPrefix(
                    "utun"
                ) || name
                .hasPrefix(
                    "ipsec"
                ) {
                return true
            }
            ptr = current.pointee.ifa_next
        }
        return false
    }

    /// Checks whether GPS coordinates plausibly match the continent implied by a timezone prefix.
    /// Uses generous bounding boxes — the goal is catching obvious cross-region spoofing
    /// (e.g. timezone says "America" but GPS is in central Europe), not pinpoint accuracy.
    /// Returns true when the continent is unknown or hard to bound (Pacific, Atlantic, Indian)
    /// so we don't produce false positives for island timezones.
    nonisolated private func gpsMatchesTimezoneContinent(_ continent: String, lat: Double, lon: Double) -> Bool {
        switch continent {
        case "America":
            // North and South America: roughly west of -25° longitude
            return lon <= -25
        case "Europe":
            // Europe: roughly -30° to 45° longitude, above 30° latitude
            return lon >= -30 && lon <= 50 && lat >= 30
        case "Asia":
            // Asia: roughly east of 25° longitude, excluding southern Africa / Australia
            return lon >= 25 && lat >= -15
        case "Africa":
            // Africa: roughly -20° to 55° longitude, -40° to 40° latitude
            return lon >= -20 && lon <= 55 && lat >= -40 && lat <= 40
        case "Australia":
            // Australia and nearby: roughly 110–160° E, south of 0°
            return lon >= 105 && lon <= 165 && lat <= 0
        case "Antarctica":
            return lat <= -55
        case "Arctic":
            return lat >= 65
        default:
            // Pacific, Atlantic, Indian ocean islands — too scattered to bound reliably
            return true
        }
    }

    @MainActor
    private func buildMotionGroup(
        now: Date
    ) -> SensorGroup {
        let orientation: String
        switch UIDevice.current.orientation {
        case .portrait: orientation = String(
            localized: "Portrait"
        )
        case .portraitUpsideDown: orientation = String(
            localized: "Portrait (Upside Down)"
        )
        case .landscapeLeft: orientation = String(
            localized: "Landscape Left"
        )
        case .landscapeRight: orientation = String(
            localized: "Landscape Right"
        )
        case .faceUp: orientation = String(
            localized: "Face Up"
        )
        case .faceDown: orientation = String(
            localized: "Face Down"
        )
        default: orientation = String(
            localized: "Unknown"
        )
        }
        
#if targetEnvironment(simulator)
        let accelX = String(
            localized: "Unavailable on Simulator"
        )
        let accelY = String(
            localized: "Unavailable on Simulator"
        )
        let accelZ = String(
            localized: "Unavailable on Simulator"
        )
        let gyroX = String(
            localized: "Unavailable on Simulator"
        )
        let gyroY = String(
            localized: "Unavailable on Simulator"
        )
        let gyroZ = String(
            localized: "Unavailable on Simulator"
        )
#else
        let accel = motionManager.accelerometerData?.acceleration
        let accelX = accel.map {
            String(
                format: "%.3f",
                $0.x
            )
        } ?? String(
            localized: "No Data"
        )
        let accelY = accel.map {
            String(
                format: "%.3f",
                $0.y
            )
        } ?? String(
            localized: "No Data"
        )
        let accelZ = accel.map {
            String(
                format: "%.3f",
                $0.z
            )
        } ?? String(
            localized: "No Data"
        )
        
        let gyro = motionManager.gyroData?.rotationRate
        let gyroX = gyro.map {
            String(
                format: "%.3f",
                $0.x
            )
        } ?? String(
            localized: "No Data"
        )
        let gyroY = gyro.map {
            String(
                format: "%.3f",
                $0.y
            )
        } ?? String(
            localized: "No Data"
        )
        let gyroZ = gyro.map {
            String(
                format: "%.3f",
                $0.z
            )
        } ?? String(
            localized: "No Data"
        )
#endif
        
        return SensorGroup(
            id: "motion",
            name: String(
                localized: "Motion & Orientation"
            ),
            sfSymbol: "gyroscope",
            readings: [
                SensorReading(
                    id: "motion.orientation",
                    label: String(
                        localized: "Orientation"
                    ),
                    value: orientation,
                    unit: nil,
                    lastUpdated: now,
                    requiresPermission: false,
                    permissionStatus: .granted
                ),
                SensorReading(
                    id: "motion.accel.x",
                    label: String(
                        localized: "Accel X"
                    ),
                    value: accelX,
                    unit: "g",
                    lastUpdated: now,
                    requiresPermission: false,
                    permissionStatus: .granted
                ),
                SensorReading(
                    id: "motion.accel.y",
                    label: String(
                        localized: "Accel Y"
                    ),
                    value: accelY,
                    unit: "g",
                    lastUpdated: now,
                    requiresPermission: false,
                    permissionStatus: .granted
                ),
                SensorReading(
                    id: "motion.accel.z",
                    label: String(
                        localized: "Accel Z"
                    ),
                    value: accelZ,
                    unit: "g",
                    lastUpdated: now,
                    requiresPermission: false,
                    permissionStatus: .granted
                ),
                SensorReading(
                    id: "motion.gyro.x",
                    label: String(
                        localized: "Gyro X"
                    ),
                    value: gyroX,
                    unit: "rad/s",
                    lastUpdated: now,
                    requiresPermission: false,
                    permissionStatus: .granted
                ),
                SensorReading(
                    id: "motion.gyro.y",
                    label: String(
                        localized: "Gyro Y"
                    ),
                    value: gyroY,
                    unit: "rad/s",
                    lastUpdated: now,
                    requiresPermission: false,
                    permissionStatus: .granted
                ),
                SensorReading(
                    id: "motion.gyro.z",
                    label: String(
                        localized: "Gyro Z"
                    ),
                    value: gyroZ,
                    unit: "rad/s",
                    lastUpdated: now,
                    requiresPermission: false,
                    permissionStatus: .granted
                ),
            ]
        )
    }
    
    @MainActor
    private func buildEnvironmentGroup(
        now: Date
    ) -> SensorGroup {
        let rawBrightness = UIApplication.shared.connectedScenes
            .compactMap {
                $0 as? UIWindowScene
            }
            .first
            .map {
                $0.screen.brightness
            } ?? 0
        let brightness = String(
            format: "%.0f%%",
            rawBrightness * 100
        )
        
        let audioSession = AVAudioSession.sharedInstance()
        let volume = String(
            format: "%.0f%%",
            audioSession.outputVolume * 100
        )
        
        let route = audioSession.currentRoute
        let headphonesConnected: String
        let headphoneTypes: [AVAudioSession.Port] = [
            .headphones,
            .bluetoothA2DP,
            .bluetoothHFP,
            .bluetoothLE,
            .airPlay
        ]
        if route.outputs
            .contains(
                where: {
                    headphoneTypes.contains(
                        $0.portType
                    )
                }) {
            headphonesConnected = String(
                localized: "Yes"
            )
        } else {
            headphonesConnected = String(
                localized: "No"
            )
        }
        
        return SensorGroup(
            id: "environment",
            name: String(
                localized: "Environment"
            ),
            sfSymbol: "speaker.wave.2.fill",
            readings: [
                SensorReading(
                    id: "env.brightness",
                    label: String(
                        localized: "Screen Brightness"
                    ),
                    value: brightness,
                    unit: nil,
                    lastUpdated: now,
                    requiresPermission: false,
                    permissionStatus: .granted
                ),
                SensorReading(
                    id: "env.volume",
                    label: String(
                        localized: "System Volume"
                    ),
                    value: volume,
                    unit: nil,
                    lastUpdated: now,
                    requiresPermission: false,
                    permissionStatus: .granted
                ),
                SensorReading(
                    id: "env.headphones",
                    label: String(
                        localized: "Headphones"
                    ),
                    value: headphonesConnected,
                    unit: nil,
                    lastUpdated: now,
                    requiresPermission: false,
                    permissionStatus: .granted
                ),
            ]
        )
    }
    
    @MainActor
    private func buildLocationGroup(
        now: Date
    ) -> SensorGroup {
        let authStatus = locationManager.authorizationStatus
        let permStatus: PermissionStatus
        
        switch authStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            permStatus = .granted
        case .denied:
            permStatus = .denied
        case .restricted:
            permStatus = .restricted
        case .notDetermined:
            permStatus = .notDetermined
        @unknown default:
            permStatus = .notAvailable
        }
        
        guard permStatus == .granted else {
            return SensorGroup(
                id: "location",
                name: String(
                    localized: "Location"
                ),
                sfSymbol: "location.slash.fill",
                readings: [
                    SensorReading(
                        id: "location.locked",
                        label: String(
                            localized: "Access"
                        ),
                        value: statusDisplayString(
                            permStatus
                        ),
                        unit: nil,
                        lastUpdated: now,
                        requiresPermission: true,
                        permissionStatus: permStatus
                    ),
                    SensorReading(
                        id: "location.tz.proxy",
                        label: String(
                            localized: "Timezone leaks region"
                        ),
                        value: "\(TimeZone.current.identifier) — visible without location permission",
                        unit: nil,
                        lastUpdated: now,
                        requiresPermission: false,
                        permissionStatus: .granted
                    ),
                ]
            )
        }
        
        // Permission is granted — begin live GPS updates so the readings below
        // stop showing "Waiting…" and refresh as the device moves. Started lazily
        // here (rather than at init) because authorization may be granted mid-session.
        if !isUpdatingLocation {
            locationManager.desiredAccuracy = kCLLocationAccuracyBest
            locationManager.startUpdatingLocation()
            isUpdatingLocation = true
        }

        let location = locationDelegate.lastLocation
        let coordinate = location.map { loc in
            String(
                format: "%.2f°, %.2f°",
                loc.coordinate.latitude,
                loc.coordinate.longitude
            )
        } ?? String(
            localized: "Waiting…"
        )
        
        let altitude = location.map { loc in
            String(
                format: "%.0f m",
                loc.altitude
            )
        } ?? String(
            localized: "Waiting…"
        )
        
        let speed = location.map { loc -> String in
            guard loc.speed >= 0 else {
                return String(
                    localized: "Unknown"
                )
            }
            return String(
                format: "%.1f m/s",
                loc.speed
            )
        } ?? String(
            localized: "Waiting…"
        )
        
        let accuracy: String
        if let loc = location {
            accuracy = loc.horizontalAccuracy <= 10 ? String(
                localized: "Precise"
            ) : String(
                localized: "Approximate"
            )
        } else {
            accuracy = String(
                localized: "Waiting…"
            )
        }
        
        // GPS vs timezone consistency — two independent signals:
        //
        // 1. UTC offset: GPS longitude ÷ 15° ≈ expected UTC hour.
        //    Tolerance is ±4h — covers western China (UTC+8, ~3h off by longitude) and all of
        //    Europe (worst case: Spain on CET, ~2.5h off by longitude). Still catches
        //    cross-hemisphere spoofing which is typically 8–14h off.
        //
        // 2. Continent prefix: "America/New_York", "Europe/Paris", "Asia/Tokyo" etc. encode
        //    both the hemisphere and latitude band. A continent mismatch catches spoofed GPS
        //    that coincidentally lands near the right UTC offset, and also catches north/south
        //    discrepancies that pure longitude offset cannot detect.
        let gpsTZConsistencyReading: SensorReading? = location.map { loc in
            let deviceTZId = TimeZone.current.identifier
            let deviceOffsetHours = TimeZone.current.secondsFromGMT() / 3600
            let gpsImpliedOffset = Int((loc.coordinate.longitude / 15.0).rounded())
            let hourDiff = abs(deviceOffsetHours - gpsImpliedOffset)

            let tzContinent = deviceTZId.split(separator: "/").first.map(String.init)
            let continentMatch = tzContinent.map {
                gpsMatchesTimezoneContinent($0, lat: loc.coordinate.latitude, lon: loc.coordinate.longitude)
            } ?? true

            let offsetMismatch = hourDiff > 4
            let continentMismatch = !continentMatch

            let value: String
            if !offsetMismatch && !continentMismatch {
                value = String(localized: "Consistent — GPS region matches timezone")
            } else {
                let formatUTC = { (h: Int) -> String in h >= 0 ? "UTC+\(h)" : "UTC\(h)" }
                var issues: [String] = []
                if continentMismatch, let continent = tzContinent {
                    issues.append(String(localized: "timezone says '\(continent)' but GPS is outside that region"))
                }
                if offsetMismatch {
                    issues.append(String(localized: "GPS implies \(formatUTC(gpsImpliedOffset)), timezone is \(formatUTC(deviceOffsetHours))"))
                }
                value = String(localized: "Inconsistent — \(issues.joined(separator: "; ")). Possible GPS spoofing.")
            }
            return SensorReading(
                id: "location.tz.gps",
                label: String(localized: "GPS vs Timezone"),
                value: value,
                unit: nil,
                lastUpdated: now,
                requiresPermission: true,
                permissionStatus: .granted
            )
        }
        
        var locationReadings: [SensorReading] = [
            SensorReading(
                id: "location.coordinate",
                label: String(
                    localized: "Coordinate"
                ),
                value: coordinate,
                unit: nil,
                lastUpdated: now,
                requiresPermission: true,
                permissionStatus: .granted
            ),
            SensorReading(
                id: "location.altitude",
                label: String(
                    localized: "Altitude"
                ),
                value: altitude,
                unit: nil,
                lastUpdated: now,
                requiresPermission: true,
                permissionStatus: .granted
            ),
            SensorReading(
                id: "location.speed",
                label: String(
                    localized: "Speed"
                ),
                value: speed,
                unit: nil,
                lastUpdated: now,
                requiresPermission: true,
                permissionStatus: .granted
            ),
            SensorReading(
                id: "location.accuracy",
                label: String(
                    localized: "Accuracy"
                ),
                value: accuracy,
                unit: nil,
                lastUpdated: now,
                requiresPermission: true,
                permissionStatus: .granted
            ),
        ]
        if let gpsTZConsistencyReading {
            locationReadings
                .append(
                    gpsTZConsistencyReading
                )
        }
        
        return SensorGroup(
            id: "location",
            name: String(
                localized: "Location"
            ),
            sfSymbol: "location.fill",
            readings: locationReadings
        )
    }
    
    private func statusDisplayString(
        _ status: PermissionStatus
    ) -> String {
        switch status {
        case .granted: String(
            localized: "Granted"
        )
        case .denied: String(
            localized: "Denied — enable in Settings"
        )
        case .notDetermined: String(
            localized: "Not requested yet"
        )
        case .restricted: String(
            localized: "Restricted by policy"
        )
        case .notAvailable: String(
            localized: "Not available"
        )
        }
    }
    
    private func localIPAddress() -> String? {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(
            &ifaddr
        ) == 0 else {
            return nil
        }
        defer {
            freeifaddrs(
                ifaddr
            )
        }
        
        var ptr = ifaddr
        while let current = ptr {
            let flags = Int32(
                current.pointee.ifa_flags
            )
            guard (
                flags & IFF_UP
            ) != 0,
                  (
                    flags & IFF_LOOPBACK
                  ) == 0,
                  current.pointee.ifa_addr.pointee.sa_family == UInt8(
                    AF_INET
                  ) else {
                ptr = current.pointee.ifa_next
                continue
            }
            var hostname = [CChar](
                repeating: 0,
                count: Int(
                    NI_MAXHOST
                )
            )
            if getnameinfo(
                current.pointee.ifa_addr,
                socklen_t(
                    current.pointee.ifa_addr.pointee.sa_len
                ),
                &hostname,
                socklen_t(
                    hostname.count
                ),
                nil,
                socklen_t(
                    0
                ),
                NI_NUMERICHOST
            ) == 0 {
                address = String(
                    cString: hostname
                )
                break
            }
            ptr = current.pointee.ifa_next
        }
        return address
    }
}

// MARK: - CLLocationManagerDelegate

private final class LocationDelegate: NSObject, CLLocationManagerDelegate, Sendable {
    private let _lastLocation = OSAllocatedUnfairLock<CLLocation?>(
        initialState: nil
    )
    
    var lastLocation: CLLocation? {
        _lastLocation
            .withLock {
                $0
            }
    }
    
    nonisolated func locationManager(
        _ manager: CLLocationManager,
        didUpdateLocations locations: [CLLocation]
    ) {
        if let loc = locations.last {
            _lastLocation
                .withLock {
                    $0 = loc
                }
        }
    }
    
    nonisolated func locationManager(
        _ manager: CLLocationManager,
        didFailWithError error: Error
    ) {
        logger
            .error(
                "Location update failed: \(error.localizedDescription)"
            )
    }
}

// MARK: - Mock data

extension SensorGroup {
    nonisolated static var mockGroups: [SensorGroup] {
        let now = Date()
        return [
            SensorGroup(
                id: "device",
                name: String(
                    localized: "Device Identity"
                ),
                sfSymbol: "iphone",
                readings: [
                    SensorReading(
                        id: "device.model",
                        label: String(
                            localized: "Model"
                        ),
                        value: "iPhone 16 Pro",
                        unit: nil,
                        lastUpdated: now,
                        requiresPermission: false,
                        permissionStatus: .granted
                    ),
                    SensorReading(
                        id: "device.system",
                        label: String(
                            localized: "iOS Version"
                        ),
                        value: "iOS 18.0",
                        unit: nil,
                        lastUpdated: now,
                        requiresPermission: false,
                        permissionStatus: .granted
                    ),
                    SensorReading(
                        id: "device.locale",
                        label: String(
                            localized: "Locale"
                        ),
                        value: "en_US",
                        unit: nil,
                        lastUpdated: now,
                        requiresPermission: false,
                        permissionStatus: .granted
                    ),
                ]
            ),
            SensorGroup(
                id: "network",
                name: String(
                    localized: "Network"
                ),
                sfSymbol: "wifi",
                readings: [
                    SensorReading(
                        id: "network.connection",
                        label: String(
                            localized: "Connection"
                        ),
                        value: "Wi-Fi",
                        unit: nil,
                        lastUpdated: now,
                        requiresPermission: false,
                        permissionStatus: .granted
                    ),
                    SensorReading(
                        id: "network.localip",
                        label: String(
                            localized: "Local IP"
                        ),
                        value: "192.168.1.42",
                        unit: nil,
                        lastUpdated: now,
                        requiresPermission: false,
                        permissionStatus: .granted
                    ),
                ]
            ),
        ]
    }
}
