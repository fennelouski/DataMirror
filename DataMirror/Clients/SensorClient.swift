// FIXED: Changed liveValue to @MainActor (was nonisolated, couldn't access MainActor shared instance)
// FIXED: Made currentPath thread-safe with OSAllocatedUnfairLock (was mutated from Sendable closure)
// FIXED: Removed unnecessary await on buildGroups() (already @MainActor)
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
            self?._currentPath
                .withLock {
                    $0 = path
                }
        }
        networkMonitor
            .start(
                queue: networkQueue
            )
        locationManager.delegate = locationDelegate
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
        
        // GPS vs timezone consistency: GPS longitude implies a rough UTC offset (15° per hour).
        // A large mismatch between that and the device timezone suggests GPS spoofing.
        let gpsTZConsistencyReading: SensorReading? = location.map { loc in
            let deviceOffsetHours = TimeZone.current.secondsFromGMT() / 3600
            let gpsImpliedOffset = Int(
                (
                    loc.coordinate.longitude / 15.0
                ).rounded()
            )
            let hourDiff = abs(
                deviceOffsetHours - gpsImpliedOffset
            )
            let formatUTC = {
                (
                    h: Int
                ) in h >= 0 ? "UTC+\(h)" : "UTC\(h)"
            }
            let value: String
            if hourDiff <= 2 {
                value = String(
                    localized: "Consistent — GPS longitude matches device timezone"
                )
            } else {
                value = String(
                    localized: "Inconsistent — GPS implies \(formatUTC(
gpsImpliedOffset
)) but timezone is \(formatUTC(
deviceOffsetHours
)). Possible GPS spoofing."
                )
            }
            return SensorReading(
                id: "location.tz.gps",
                label: String(
                    localized: "GPS vs Timezone"
                ),
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
