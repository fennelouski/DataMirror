# DataMirror

DataMirror is an iOS privacy education app that shows you exactly what sensor data your iPhone exposes and what each permission unlocks for apps and advertisers. Everything stays on-device — no analytics, no tracking, no data leaves your phone.

## Architecture

Built with [The Composable Architecture (TCA)](https://github.com/pointfreeco/swift-composable-architecture) by Point-Free.

```
DataMirrorApp
  └── AppFeature
        ├── DashboardFeature (live sensor readings + exposure score)
        ├── PermissionsFeature → PermissionDetailFeature (sheet)
        ├── HistoryFeature (score history with Swift Charts)
        ├── AboutFeature
        └── PrimerFeature (first-launch onboarding)

Clients (Dependency Layer):
  ├── SensorClient       — CoreMotion, CoreLocation, Network, UIDevice
  ├── PermissionClient    — CLLocationManager, AVCaptureDevice, CNContactStore, etc.
  ├── UserDefaultsClient  — Wraps UserDefaults.standard
  └── SharedDefaultsClient — Wraps App Group suite (group.com.datamirror)
```

## How to Build

1. **Clone and open** the project in Xcode 26+
2. **SPM dependencies** resolve automatically (ComposableArchitecture 1.x)
3. **App Group setup** (required for widget + history):
   - Select the `DataMirror` target → Signing & Capabilities → + App Groups → `group.com.datamirror`
4. **Widget Extension** (optional):
   - File → New → Target → Widget Extension → name it `DataMirrorWidget`
   - Replace the generated Swift file with `DataMirrorWidget/DataMirrorWidget.swift`
   - Add the same App Group (`group.com.datamirror`) to the widget target
5. **Build & Run** on simulator or device (iOS 17.0+)

## Known Simulator Limitations

- **CoreMotion** — Accelerometer and gyroscope readings show "Unavailable on Simulator"
- **CoreTelephony** — Carrier name shows "Unavailable on Simulator"
- **Motion & Fitness permission** — Returns `.notAvailable` on simulator
- **Location** — Works via simulated location in Xcode
- **Widget** — Renders placeholder data in the widget gallery; real scores require the main app to run

## Planned Future Phases

- Ads metadata layer — surface which SDKs/trackers are embedded in installed apps
- Data broker opt-out integration — link to opt-out flows for major data brokers
- Export report — generate a shareable privacy summary PDF
- watchOS companion — exposure score on your wrist
