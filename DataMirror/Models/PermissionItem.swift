import Foundation

// MARK: - PermissionType

enum PermissionType: String, Equatable, CaseIterable, Sendable, Hashable {
    case locationAlways
    case locationWhenInUse
    case preciseLocation
    case camera
    case microphone
    case motionFitness
    case mediaLibrary
    case contacts
    case calendar
    case reminders
    case notes
    case photosReadWrite
    case photosLimited
    case photosAddOnly
    case healthRead
    case healthWrite
    case bluetooth
    case localNetwork
    case nearbyInteractions
    case nfc
    case faceID
    case tracking
    case siri
    case speechRecognition
    case notifications
    case backgroundAppRefresh
    case homeKit
    case classKit
    case focusStatus
}

// MARK: - PermissionCategory

enum PermissionCategory: String, Equatable, CaseIterable, Sendable {
    case location
    case mediaSensors
    case communicationData
    case filesStorage
    case health
    case deviceConnectivity
    case identityPrivacy
    case notificationsBackground
    case homeExternal
    case focusSystem

    var displayName: String {
        switch self {
        case .location: String(localized: "Location")
        case .mediaSensors: String(localized: "Media & Sensors")
        case .communicationData: String(localized: "Communication & Data")
        case .filesStorage: String(localized: "Files & Storage")
        case .health: String(localized: "Health")
        case .deviceConnectivity: String(localized: "Device & Connectivity")
        case .identityPrivacy: String(localized: "Identity & Privacy")
        case .notificationsBackground: String(localized: "Notifications & Background")
        case .homeExternal: String(localized: "Home & External")
        case .focusSystem: String(localized: "Focus & System")
        }
    }

    var sfSymbol: String {
        switch self {
        case .location: "location.fill"
        case .mediaSensors: "camera.fill"
        case .communicationData: "person.2.fill"
        case .filesStorage: "folder.fill"
        case .health: "heart.fill"
        case .deviceConnectivity: "dot.radiowaves.left.and.right"
        case .identityPrivacy: "person.badge.shield.checkmark.fill"
        case .notificationsBackground: "bell.fill"
        case .homeExternal: "house.fill"
        case .focusSystem: "moon.fill"
        }
    }
}

// MARK: - PermissionStatus

enum PermissionStatus: Equatable, Sendable {
    case granted
    case denied
    case notDetermined
    case restricted
    case notAvailable
}

// MARK: - SensitivityTier

enum SensitivityTier: Equatable, Sendable, CaseIterable {
    case high
    case medium
    case low

    var displayName: String {
        switch self {
        case .high: String(localized: "High Sensitivity")
        case .medium: String(localized: "Medium Sensitivity")
        case .low: String(localized: "Low Sensitivity")
        }
    }
}

// MARK: - GrantLevel

struct GrantLevel: Equatable, Identifiable, Sendable {
    let id: String
    let label: String
    let description: String
    let dataAccessSummary: String
    let isCurrentSelection: Bool
}

// MARK: - PermissionItem

struct PermissionItem: Equatable, Identifiable, Sendable {
    let id: PermissionType
    let name: String
    let category: PermissionCategory
    let sfSymbol: String
    let sensitivityTier: SensitivityTier
    let isUserPromptable: Bool
    let systemNote: String?
    var status: PermissionStatus
    let grantLevels: [GrantLevel]
    let appCapabilities: [String]
    let advertiserInferences: [String]
    let ungatedData: [String]
}

// MARK: - allItems

extension PermissionItem {
    nonisolated static let allItems: [PermissionItem] = [

        // MARK: locationWhenInUse
        PermissionItem(
            id: .locationWhenInUse,
            name: String(localized: "Location When In Use"),
            category: .location,
            sfSymbol: "location",
            sensitivityTier: .high,
            isUserPromptable: true,
            systemNote: nil,
            status: .notDetermined,
            grantLevels: [
                GrantLevel(
                    id: "locationWhenInUse.whileUsing",
                    label: String(localized: "While Using App"),
                    description: String(localized: "The app can access your location only while it is open and visible on screen."),
                    dataAccessSummary: String(localized: "Latitude and longitude coordinate pair, accuracy radius, altitude, and speed from GPS/cell/Wi-Fi triangulation. Active during foreground sessions only."),
                    isCurrentSelection: false
                ),
                GrantLevel(
                    id: "locationWhenInUse.never",
                    label: String(localized: "Never"),
                    description: String(localized: "The app cannot access your location at all."),
                    dataAccessSummary: String(localized: "No location data is provided to the app."),
                    isCurrentSelection: false
                ),
            ],
            appCapabilities: [
                String(localized: "Access your location while the app is in the foreground"),
                String(localized: "Show nearby results, directions, or local content"),
                String(localized: "Tag photos and posts with your current location"),
            ],
            advertiserInferences: [
                String(localized: "Approximate home and work areas from active sessions"),
                String(localized: "Local retail preferences from foreground usage"),
                String(localized: "Restaurant and shopping habits"),
            ],
            ungatedData: [
                String(localized: "Your IP address approximates your city regardless of location permission"),
                String(localized: "Device timezone reveals your general region"),
                String(localized: "App Store region and locale further narrow geographic inference"),
            ]
        ),

        // MARK: locationAlways
        PermissionItem(
            id: .locationAlways,
            name: String(localized: "Location Always"),
            category: .location,
            sfSymbol: "location.fill",
            sensitivityTier: .high,
            isUserPromptable: true,
            systemNote: nil,
            status: .notDetermined,
            grantLevels: [
                GrantLevel(
                    id: "locationAlways.always",
                    label: String(localized: "Always"),
                    description: String(localized: "The app can access your location at any time, including when the app is closed or in the background."),
                    dataAccessSummary: String(localized: "Continuous GPS/cell/Wi-Fi coordinates even when device screen is off. Enables geofencing triggers, significant location change events, and background location history construction."),
                    isCurrentSelection: false
                ),
                GrantLevel(
                    id: "locationAlways.whileUsing",
                    label: String(localized: "While Using App"),
                    description: String(localized: "The app can access your location only while it is open and visible on screen."),
                    dataAccessSummary: String(localized: "Foreground-only coordinate access. Geofencing and background updates are blocked."),
                    isCurrentSelection: false
                ),
                GrantLevel(
                    id: "locationAlways.never",
                    label: String(localized: "Never"),
                    description: String(localized: "The app cannot access your location at all."),
                    dataAccessSummary: String(localized: "No location data is provided to the app."),
                    isCurrentSelection: false
                ),
            ],
            appCapabilities: [
                String(localized: "Background location tracking even when app is closed"),
                String(localized: "Geofencing — trigger actions when entering or leaving areas"),
                String(localized: "Continuous location history construction"),
                String(localized: "Location-based push notifications"),
            ],
            advertiserInferences: [
                String(localized: "Home and work address from dwell patterns"),
                String(localized: "Daily commute route and timing"),
                String(localized: "Frequently visited places: gyms, churches, hospitals"),
                String(localized: "Travel behavior and income proxies"),
                String(localized: "Political and religious affiliation from visited locations"),
            ],
            ungatedData: [
                String(localized: "Your IP address approximates your city regardless of location permission"),
                String(localized: "Device timezone reveals your general region"),
                String(localized: "App Store region and locale further narrow geographic inference"),
            ]
        ),

        // MARK: preciseLocation
        PermissionItem(
            id: .preciseLocation,
            name: String(localized: "Precise Location"),
            category: .location,
            sfSymbol: "location.magnifyingglass",
            sensitivityTier: .high,
            isUserPromptable: false,
            systemNote: String(localized: "Precise location is a toggle in iOS Settings under your location permission, not a separate permission prompt."),
            status: .notDetermined,
            grantLevels: [
                GrantLevel(
                    id: "preciseLocation.precise",
                    label: String(localized: "Precise"),
                    description: String(localized: "The app receives your exact GPS coordinates to within a few meters."),
                    dataAccessSummary: String(localized: "Exact latitude/longitude accurate to ±5 m or better. Enables street-level tracking and route reconstruction."),
                    isCurrentSelection: false
                ),
                GrantLevel(
                    id: "preciseLocation.approximate",
                    label: String(localized: "Approximate"),
                    description: String(localized: "The app receives a fuzzy location accurate to roughly 3 km, not your exact position."),
                    dataAccessSummary: String(localized: "Neighborhood or city-level coordinate only. Precise address and route cannot be determined."),
                    isCurrentSelection: false
                ),
            ],
            appCapabilities: [
                String(localized: "Receive exact GPS coordinates accurate to a few meters"),
                String(localized: "Enable turn-by-turn navigation and street-level features"),
                String(localized: "Accurately geotag photos and checkins"),
            ],
            advertiserInferences: [
                String(localized: "Street-level location enables precise dwell-time analysis at specific venues"),
                String(localized: "Exact routes allow full daily movement reconstruction"),
                String(localized: "Precise coordinates can uniquely identify your home and workplace"),
            ],
            ungatedData: [
                String(localized: "Approximate location via IP is still accessible without this toggle"),
                String(localized: "Cell tower region is observable by carrier partners"),
                String(localized: "Wi-Fi SSID can be used to infer location without GPS"),
            ]
        ),

        // MARK: camera
        PermissionItem(
            id: .camera,
            name: String(localized: "Camera"),
            category: .mediaSensors,
            sfSymbol: "camera.fill",
            sensitivityTier: .high,
            isUserPromptable: true,
            systemNote: nil,
            status: .notDetermined,
            grantLevels: [
                GrantLevel(
                    id: "camera.allow",
                    label: String(localized: "Allow"),
                    description: String(localized: "The app can activate and use your device's camera to capture photos and video."),
                    dataAccessSummary: String(localized: "Live camera frames, captured images and video, QR code scans, and facial geometry from the TrueDepth camera if used."),
                    isCurrentSelection: false
                ),
                GrantLevel(
                    id: "camera.dontAllow",
                    label: String(localized: "Don't Allow"),
                    description: String(localized: "The app cannot access the camera."),
                    dataAccessSummary: String(localized: "No camera frames or images are accessible."),
                    isCurrentSelection: false
                ),
            ],
            appCapabilities: [
                String(localized: "Capture photos and video in real time"),
                String(localized: "Scan QR codes and barcodes"),
                String(localized: "Scan documents and faces"),
                String(localized: "Conduct video calls"),
            ],
            advertiserInferences: [
                String(localized: "EXIF data in saved photos reveals precise locations"),
                String(localized: "Faces in photos build demographic models"),
                String(localized: "Scanned content can reveal product preferences"),
            ],
            ungatedData: [
                String(localized: "Device model is accessible without any permission"),
                String(localized: "Screen dimensions and display scale are readable without permission"),
                String(localized: "App usage timing can infer camera-adjacent behavior"),
            ]
        ),

        // MARK: microphone
        PermissionItem(
            id: .microphone,
            name: String(localized: "Microphone"),
            category: .mediaSensors,
            sfSymbol: "mic.fill",
            sensitivityTier: .high,
            isUserPromptable: true,
            systemNote: nil,
            status: .notDetermined,
            grantLevels: [
                GrantLevel(
                    id: "microphone.allow",
                    label: String(localized: "Allow"),
                    description: String(localized: "The app can record audio through the device microphone."),
                    dataAccessSummary: String(localized: "Raw PCM audio stream. Everything audible near the device including conversations, ambient sounds, and media playback."),
                    isCurrentSelection: false
                ),
                GrantLevel(
                    id: "microphone.dontAllow",
                    label: String(localized: "Don't Allow"),
                    description: String(localized: "The app cannot access the microphone."),
                    dataAccessSummary: String(localized: "No audio input is accessible to the app."),
                    isCurrentSelection: false
                ),
            ],
            appCapabilities: [
                String(localized: "Record audio during active use"),
                String(localized: "Transcribe speech to text"),
                String(localized: "Conduct voice and video calls"),
                String(localized: "Analyze ambient sounds"),
            ],
            advertiserInferences: [
                String(localized: "Spoken content can be analyzed for interests and intent"),
                String(localized: "Background audio reveals home and social environment"),
                String(localized: "Voice patterns identify household members"),
            ],
            ungatedData: [
                String(localized: "Device model and OS version signal audio hardware capability"),
                String(localized: "App session timing correlates with vocal activity periods"),
                String(localized: "Volume settings and headphone state are readable without permission"),
            ]
        ),

        // MARK: motionFitness
        PermissionItem(
            id: .motionFitness,
            name: String(localized: "Motion & Fitness"),
            category: .mediaSensors,
            sfSymbol: "figure.walk",
            sensitivityTier: .high,
            isUserPromptable: true,
            systemNote: nil,
            status: .notDetermined,
            grantLevels: [
                GrantLevel(
                    id: "motionFitness.allow",
                    label: String(localized: "Allow"),
                    description: String(localized: "The app can read step counts, workout data, and raw sensor motion data."),
                    dataAccessSummary: String(localized: "Pedometer data (steps, distance, floors), activity classification (walking, running, cycling, driving), raw accelerometer and gyroscope readings."),
                    isCurrentSelection: false
                ),
                GrantLevel(
                    id: "motionFitness.dontAllow",
                    label: String(localized: "Don't Allow"),
                    description: String(localized: "The app cannot access motion or fitness sensors."),
                    dataAccessSummary: String(localized: "No motion or pedometer data is available."),
                    isCurrentSelection: false
                ),
            ],
            appCapabilities: [
                String(localized: "Read step counts and distance"),
                String(localized: "Detect activity type: walking, running, cycling"),
                String(localized: "Access workout and fitness history"),
            ],
            advertiserInferences: [
                String(localized: "Activity level informs health and insurance risk models"),
                String(localized: "Step counts can infer commute method and lifestyle"),
                String(localized: "Fitness habits signal disposable income and age range"),
            ],
            ungatedData: [
                String(localized: "Device accelerometer data is accessible to browsers via DeviceMotion API without a prompt"),
                String(localized: "Battery drain patterns can correlate with physical activity"),
                String(localized: "GPS speed (from location permission) is a proxy for activity type"),
            ]
        ),

        // MARK: mediaLibrary
        PermissionItem(
            id: .mediaLibrary,
            name: String(localized: "Media Library"),
            category: .mediaSensors,
            sfSymbol: "music.note.list",
            sensitivityTier: .medium,
            isUserPromptable: true,
            systemNote: nil,
            status: .notDetermined,
            grantLevels: [
                GrantLevel(
                    id: "mediaLibrary.allow",
                    label: String(localized: "Allow"),
                    description: String(localized: "The app can access your Apple Music library, playlists, and subscription status."),
                    dataAccessSummary: String(localized: "Full song library, playlist titles and contents, play counts, ratings, recently played tracks, and Apple Music subscription tier."),
                    isCurrentSelection: false
                ),
                GrantLevel(
                    id: "mediaLibrary.dontAllow",
                    label: String(localized: "Don't Allow"),
                    description: String(localized: "The app cannot access your music library or subscription status."),
                    dataAccessSummary: String(localized: "No music catalog or subscription data is accessible."),
                    isCurrentSelection: false
                ),
            ],
            appCapabilities: [
                String(localized: "Browse your full Apple Music library and playlists"),
                String(localized: "Read play counts and recently played tracks"),
                String(localized: "Detect Apple Music subscription status"),
            ],
            advertiserInferences: [
                String(localized: "Music taste reveals demographic and psychographic profile"),
                String(localized: "Play counts signal emotional state and daily routine"),
                String(localized: "Subscription status indicates willingness to pay for digital services"),
            ],
            ungatedData: [
                String(localized: "Default music app choice is partially inferred from app usage"),
                String(localized: "Volume and audio route state are readable without permission"),
                String(localized: "Device language and locale correlate with regional music preferences"),
            ]
        ),

        // MARK: contacts
        PermissionItem(
            id: .contacts,
            name: String(localized: "Contacts"),
            category: .communicationData,
            sfSymbol: "person.2.fill",
            sensitivityTier: .high,
            isUserPromptable: true,
            systemNote: nil,
            status: .notDetermined,
            grantLevels: [
                GrantLevel(
                    id: "contacts.allow",
                    label: String(localized: "Allow"),
                    description: String(localized: "The app can read all contacts stored on your device including names, phone numbers, emails, and addresses."),
                    dataAccessSummary: String(localized: "Full CNContact fields: names, phone numbers, email addresses, postal addresses, birthdays, job titles, organizations, social profiles, relationships, notes, thumbnails, and creation/modification dates."),
                    isCurrentSelection: false
                ),
                GrantLevel(
                    id: "contacts.dontAllow",
                    label: String(localized: "Don't Allow"),
                    description: String(localized: "The app cannot access your contacts list."),
                    dataAccessSummary: String(localized: "No contact data is accessible."),
                    isCurrentSelection: false
                ),
            ],
            appCapabilities: [
                String(localized: "Read all names, phone numbers, and email addresses"),
                String(localized: "Find friends on the platform"),
                String(localized: "Autofill contact info in forms"),
                String(localized: "Sync contacts to a remote server"),
            ],
            advertiserInferences: [
                String(localized: "Social graph reveals relationships and demographics"),
                String(localized: "Contact names and emails can be matched to ad platforms"),
                String(localized: "Household size and family status can be inferred"),
            ],
            ungatedData: [
                String(localized: "Your own phone number is accessible to apps through the carrier without a contacts prompt"),
                String(localized: "Device account email (Apple ID) can be used to correlate contact lists across devices"),
                String(localized: "App referral codes reveal social connections without reading the address book"),
            ]
        ),

        // MARK: calendar
        PermissionItem(
            id: .calendar,
            name: String(localized: "Calendar"),
            category: .communicationData,
            sfSymbol: "calendar",
            sensitivityTier: .medium,
            isUserPromptable: true,
            systemNote: nil,
            status: .notDetermined,
            grantLevels: [
                GrantLevel(
                    id: "calendar.fullAccess",
                    label: String(localized: "Full Access"),
                    description: String(localized: "The app can read, create, edit, and delete all calendar events."),
                    dataAccessSummary: String(localized: "All EKEvent fields: title, start/end times, location, attendees, notes, URL, recurrence rules, alarms, and calendar source."),
                    isCurrentSelection: false
                ),
                GrantLevel(
                    id: "calendar.addOnly",
                    label: String(localized: "Add Only"),
                    description: String(localized: "The app can create new calendar events but cannot read existing ones."),
                    dataAccessSummary: String(localized: "Write-only access. The app sees only events it creates; existing calendar data is not readable."),
                    isCurrentSelection: false
                ),
                GrantLevel(
                    id: "calendar.dontAllow",
                    label: String(localized: "Don't Allow"),
                    description: String(localized: "The app cannot access the calendar."),
                    dataAccessSummary: String(localized: "No calendar data is accessible."),
                    isCurrentSelection: false
                ),
            ],
            appCapabilities: [
                String(localized: "Read existing calendar events and attendees"),
                String(localized: "Create, edit, and delete events"),
                String(localized: "Suggest scheduling based on your availability"),
            ],
            advertiserInferences: [
                String(localized: "Medical, legal, and financial appointments reveal intent"),
                String(localized: "Travel plans enable pre-trip targeting"),
                String(localized: "Social patterns reveal relationship status"),
            ],
            ungatedData: [
                String(localized: "App invites and meeting links arrive via email, revealing scheduling patterns without calendar access"),
                String(localized: "Push notification open-rate timing correlates with calendar schedule"),
                String(localized: "Timezone and locale imply regional event patterns"),
            ]
        ),

        // MARK: reminders
        PermissionItem(
            id: .reminders,
            name: String(localized: "Reminders"),
            category: .communicationData,
            sfSymbol: "list.bullet",
            sensitivityTier: .medium,
            isUserPromptable: true,
            systemNote: nil,
            status: .notDetermined,
            grantLevels: [
                GrantLevel(
                    id: "reminders.fullAccess",
                    label: String(localized: "Full Access"),
                    description: String(localized: "The app can read, create, edit, and complete all reminders and lists."),
                    dataAccessSummary: String(localized: "All EKReminder fields: title, due date, notes, priority, completion status, and list membership."),
                    isCurrentSelection: false
                ),
                GrantLevel(
                    id: "reminders.dontAllow",
                    label: String(localized: "Don't Allow"),
                    description: String(localized: "The app cannot access reminders."),
                    dataAccessSummary: String(localized: "No reminder data is accessible."),
                    isCurrentSelection: false
                ),
            ],
            appCapabilities: [
                String(localized: "Read all reminder lists and tasks"),
                String(localized: "Create new reminders"),
                String(localized: "Complete or delete reminders"),
            ],
            advertiserInferences: [
                String(localized: "Shopping lists reveal product interests"),
                String(localized: "Task content can signal life events"),
            ],
            ungatedData: [
                String(localized: "Siri suggestion patterns can infer reminder topics without direct access"),
                String(localized: "Notification interaction data leaks reminder cadence"),
                String(localized: "App launch timing correlates with reminder-driven behavior"),
            ]
        ),

        // MARK: notes
        PermissionItem(
            id: .notes,
            name: String(localized: "Notes"),
            category: .communicationData,
            sfSymbol: "note.text",
            sensitivityTier: .medium,
            isUserPromptable: false,
            systemNote: String(localized: "iOS does not allow third-party apps to request access to Notes. Notes remain private to the system."),
            status: .notAvailable,
            grantLevels: [
                GrantLevel(
                    id: "notes.systemOnly",
                    label: String(localized: "System Only"),
                    description: String(localized: "Only Apple's own Notes app and iCloud can access your notes. Third-party apps cannot request this access."),
                    dataAccessSummary: String(localized: "No third-party access possible. Notes data stays within Apple's iCloud infrastructure."),
                    isCurrentSelection: false
                ),
            ],
            appCapabilities: [
                String(localized: "Third-party apps cannot read Notes content — this is system-only"),
                String(localized: "Apps can open the Notes app via URL scheme but cannot read content"),
            ],
            advertiserInferences: [
                String(localized: "No direct advertiser access is possible for Notes content"),
                String(localized: "Note-sharing via other apps may expose content through those apps"),
            ],
            ungatedData: [
                String(localized: "Notes shared as links expose content to recipient apps"),
                String(localized: "Text copied from Notes enters the pasteboard, which apps can read"),
                String(localized: "iCloud sync metadata may be visible to Apple's servers"),
            ]
        ),

        // MARK: photosReadWrite
        PermissionItem(
            id: .photosReadWrite,
            name: String(localized: "Photos (Full Access)"),
            category: .filesStorage,
            sfSymbol: "photo.fill",
            sensitivityTier: .high,
            isUserPromptable: true,
            systemNote: nil,
            status: .notDetermined,
            grantLevels: [
                GrantLevel(
                    id: "photosReadWrite.fullAccess",
                    label: String(localized: "Full Access"),
                    description: String(localized: "The app can read, edit, and delete every photo and video in your library."),
                    dataAccessSummary: String(localized: "All PHAsset metadata: GPS coordinates, EXIF data (camera make/model, aperture, ISO, shutter speed), creation date, faces, albums, burst groups, and iCloud sync status. Full pixel data for all images and videos."),
                    isCurrentSelection: false
                ),
                GrantLevel(
                    id: "photosReadWrite.limited",
                    label: String(localized: "Limited Access"),
                    description: String(localized: "The app can only access the specific photos you select. iOS shows a picker limited to your chosen set."),
                    dataAccessSummary: String(localized: "Same full metadata and pixel data as above, but restricted to the user-chosen subset of photos."),
                    isCurrentSelection: false
                ),
                GrantLevel(
                    id: "photosReadWrite.addOnly",
                    label: String(localized: "Add Only"),
                    description: String(localized: "The app can save new photos to your library but cannot read existing ones."),
                    dataAccessSummary: String(localized: "Write access only. No existing photo data is accessible."),
                    isCurrentSelection: false
                ),
                GrantLevel(
                    id: "photosReadWrite.none",
                    label: String(localized: "None"),
                    description: String(localized: "The app cannot access the photo library at all."),
                    dataAccessSummary: String(localized: "No photo library data is accessible."),
                    isCurrentSelection: false
                ),
            ],
            appCapabilities: [
                String(localized: "Browse your entire photo library"),
                String(localized: "Upload photos to remote servers"),
                String(localized: "Edit and delete photos"),
                String(localized: "Read EXIF metadata including location"),
                String(localized: "Perform face and object recognition"),
            ],
            advertiserInferences: [
                String(localized: "Faces enable demographic profiling"),
                String(localized: "Location metadata traces physical movements"),
                String(localized: "Product and brand recognition from photos"),
                String(localized: "Lifestyle and interest inference from image content"),
            ],
            ungatedData: [
                String(localized: "Photos shared in apps expose EXIF metadata to those app servers"),
                String(localized: "Photo count and storage size are readable via device storage APIs"),
                String(localized: "iCloud Photo Library sync status leaks photo library size to Apple"),
            ]
        ),

        // MARK: photosLimited
        PermissionItem(
            id: .photosLimited,
            name: String(localized: "Photos (Limited)"),
            category: .filesStorage,
            sfSymbol: "photo.on.rectangle",
            sensitivityTier: .high,
            isUserPromptable: true,
            systemNote: nil,
            status: .notDetermined,
            grantLevels: [
                GrantLevel(
                    id: "photosLimited.selectedPhotos",
                    label: String(localized: "Selected Photos"),
                    description: String(localized: "The app can access only the specific photos you chose via the iOS photo picker."),
                    dataAccessSummary: String(localized: "Full PHAsset metadata (GPS, EXIF, creation date) and pixel data for the user-selected subset only. The app cannot enumerate or discover other photos."),
                    isCurrentSelection: false
                ),
                GrantLevel(
                    id: "photosLimited.none",
                    label: String(localized: "None"),
                    description: String(localized: "The app cannot access any photos."),
                    dataAccessSummary: String(localized: "No photo data is accessible."),
                    isCurrentSelection: false
                ),
            ],
            appCapabilities: [
                String(localized: "Access only photos explicitly selected by you in the iOS picker"),
                String(localized: "Read full metadata including GPS location for selected photos"),
                String(localized: "Upload selected photos to remote servers"),
            ],
            advertiserInferences: [
                String(localized: "Selected photos still contain full GPS and EXIF metadata"),
                String(localized: "Photo selection patterns reveal interests and subjects"),
                String(localized: "Faces in selected photos enable demographic inference"),
            ],
            ungatedData: [
                String(localized: "Photos shared via other channels expose full EXIF data"),
                String(localized: "iCloud shared album links expose photos to recipients"),
                String(localized: "Screenshots taken within apps are saved without permission prompts"),
            ]
        ),

        // MARK: photosAddOnly
        PermissionItem(
            id: .photosAddOnly,
            name: String(localized: "Photos (Add Only)"),
            category: .filesStorage,
            sfSymbol: "photo.badge.plus",
            sensitivityTier: .low,
            isUserPromptable: true,
            systemNote: nil,
            status: .notDetermined,
            grantLevels: [
                GrantLevel(
                    id: "photosAddOnly.addOnly",
                    label: String(localized: "Add Only"),
                    description: String(localized: "The app can save new photos and videos to your library but cannot read or access any existing photos."),
                    dataAccessSummary: String(localized: "Write-only access. Saved assets become part of your library but the app cannot read back any photos."),
                    isCurrentSelection: false
                ),
                GrantLevel(
                    id: "photosAddOnly.none",
                    label: String(localized: "None"),
                    description: String(localized: "The app cannot add photos to your library."),
                    dataAccessSummary: String(localized: "No photo library interaction is possible."),
                    isCurrentSelection: false
                ),
            ],
            appCapabilities: [
                String(localized: "Save new photos and videos to your library"),
                String(localized: "Cannot read or access existing photos"),
            ],
            advertiserInferences: [
                String(localized: "Minimal direct advertising value"),
                String(localized: "Confirms the app has camera or content creation capability"),
            ],
            ungatedData: [
                String(localized: "Saved photos' EXIF data becomes readable via Photos app"),
                String(localized: "Photo count growth rate is observable via storage APIs"),
                String(localized: "App identity is embedded in saved photo metadata"),
            ]
        ),

        // MARK: healthRead
        PermissionItem(
            id: .healthRead,
            name: String(localized: "Health (Read)"),
            category: .health,
            sfSymbol: "heart.fill",
            sensitivityTier: .high,
            isUserPromptable: true,
            systemNote: nil,
            status: .notDetermined,
            grantLevels: [
                GrantLevel(
                    id: "healthRead.allow",
                    label: String(localized: "Allow"),
                    description: String(localized: "The app can read the health data types you approve from the Health app."),
                    dataAccessSummary: String(localized: "Approved HKSampleType data: heart rate, steps, sleep analysis, blood glucose, blood pressure, weight, reproductive health, medications, lab results, and any other granted data type."),
                    isCurrentSelection: false
                ),
                GrantLevel(
                    id: "healthRead.dontAllow",
                    label: String(localized: "Don't Allow"),
                    description: String(localized: "The app cannot read any Health data."),
                    dataAccessSummary: String(localized: "No health data is accessible."),
                    isCurrentSelection: false
                ),
            ],
            appCapabilities: [
                String(localized: "Read health metrics: heart rate, sleep, weight"),
                String(localized: "Access medical records and prescriptions"),
                String(localized: "Read reproductive health data"),
                String(localized: "Track chronic condition data"),
            ],
            advertiserInferences: [
                String(localized: "Chronic conditions are among the highest-value ad targeting signals"),
                String(localized: "Sleep data reveals stress and schedule patterns"),
                String(localized: "Reproductive health data is highly sensitive and regulated"),
            ],
            ungatedData: [
                String(localized: "Motion and fitness data accessible via separate permission still infers health status"),
                String(localized: "Purchase history from other apps can reveal pharmacy and supplement buying"),
                String(localized: "Apple Health app usage frequency is a proxy for health consciousness"),
            ]
        ),

        // MARK: healthWrite
        PermissionItem(
            id: .healthWrite,
            name: String(localized: "Health (Write)"),
            category: .health,
            sfSymbol: "heart.text.square.fill",
            sensitivityTier: .high,
            isUserPromptable: true,
            systemNote: nil,
            status: .notDetermined,
            grantLevels: [
                GrantLevel(
                    id: "healthWrite.allow",
                    label: String(localized: "Allow"),
                    description: String(localized: "The app can write health data to the Health app for the data types you approve."),
                    dataAccessSummary: String(localized: "The app can add new HKSamples for approved types. Written data becomes part of your Health profile and readable by other apps with read permission."),
                    isCurrentSelection: false
                ),
                GrantLevel(
                    id: "healthWrite.dontAllow",
                    label: String(localized: "Don't Allow"),
                    description: String(localized: "The app cannot write any Health data."),
                    dataAccessSummary: String(localized: "No health data can be written by this app."),
                    isCurrentSelection: false
                ),
            ],
            appCapabilities: [
                String(localized: "Write health metrics to the Health app"),
                String(localized: "Log workouts, nutrition, and vitals on your behalf"),
                String(localized: "Integrate sensor data from third-party hardware into HealthKit"),
            ],
            advertiserInferences: [
                String(localized: "Write access confirms the app is collecting health-relevant measurements"),
                String(localized: "Written data sources reveal which health devices you use"),
                String(localized: "Frequency of writes indicates health tracking engagement level"),
            ],
            ungatedData: [
                String(localized: "Written health data is readable by all other apps granted read permission"),
                String(localized: "HealthKit source list reveals which health apps are installed"),
                String(localized: "Data types written reveal health concerns without reading prior data"),
            ]
        ),

        // MARK: bluetooth
        PermissionItem(
            id: .bluetooth,
            name: String(localized: "Bluetooth"),
            category: .deviceConnectivity,
            sfSymbol: "dot.radiowaves.left.and.right",
            sensitivityTier: .medium,
            isUserPromptable: true,
            systemNote: nil,
            status: .notDetermined,
            grantLevels: [
                GrantLevel(
                    id: "bluetooth.allow",
                    label: String(localized: "Allow"),
                    description: String(localized: "The app can scan for and connect to nearby Bluetooth devices."),
                    dataAccessSummary: String(localized: "List of all nearby Bluetooth device identifiers (UUIDs), signal strength (RSSI), advertised service UUIDs, and device names. Enables persistent indoor location profiling via beacon scanning."),
                    isCurrentSelection: false
                ),
                GrantLevel(
                    id: "bluetooth.dontAllow",
                    label: String(localized: "Don't Allow"),
                    description: String(localized: "The app cannot use Bluetooth."),
                    dataAccessSummary: String(localized: "No Bluetooth scanning or connection is possible."),
                    isCurrentSelection: false
                ),
            ],
            appCapabilities: [
                String(localized: "Scan for nearby Bluetooth devices"),
                String(localized: "Connect to accessories and peripherals"),
                String(localized: "Estimate indoor location via beacons"),
            ],
            advertiserInferences: [
                String(localized: "Nearby device discovery enables indoor location profiling"),
                String(localized: "Cross-device identity linking via shared Bluetooth environments"),
            ],
            ungatedData: [
                String(localized: "Classic Bluetooth state (on/off) is readable without permission"),
                String(localized: "Paired device list length is partially inferred from app behavior"),
                String(localized: "BLE beacon data from retail stores is collected by store apps already granted access"),
            ]
        ),

        // MARK: localNetwork
        PermissionItem(
            id: .localNetwork,
            name: String(localized: "Local Network"),
            category: .deviceConnectivity,
            sfSymbol: "network",
            sensitivityTier: .medium,
            isUserPromptable: true,
            systemNote: nil,
            status: .notDetermined,
            grantLevels: [
                GrantLevel(
                    id: "localNetwork.allow",
                    label: String(localized: "Allow"),
                    description: String(localized: "The app can discover and communicate with devices on your local Wi-Fi network."),
                    dataAccessSummary: String(localized: "mDNS/Bonjour service discovery, device hostnames, IP addresses of local network devices, router manufacturer, and network device inventory. Enables home network fingerprinting."),
                    isCurrentSelection: false
                ),
                GrantLevel(
                    id: "localNetwork.dontAllow",
                    label: String(localized: "Don't Allow"),
                    description: String(localized: "The app cannot access the local network."),
                    dataAccessSummary: String(localized: "No local network discovery is possible."),
                    isCurrentSelection: false
                ),
            ],
            appCapabilities: [
                String(localized: "Discover devices on your local Wi-Fi network"),
                String(localized: "Connect to local servers and printers"),
                String(localized: "Fingerprint your home network topology"),
            ],
            advertiserInferences: [
                String(localized: "Home network topology creates a persistent device fingerprint"),
                String(localized: "Connected devices reveal household size and tech usage"),
            ],
            ungatedData: [
                String(localized: "Public IP address is visible to all remote servers without any permission"),
                String(localized: "Wi-Fi network name (SSID) is readable without local network permission in many scenarios"),
                String(localized: "Network latency patterns reveal router type and internet provider"),
            ]
        ),

        // MARK: nearbyInteractions
        PermissionItem(
            id: .nearbyInteractions,
            name: String(localized: "Nearby Interactions"),
            category: .deviceConnectivity,
            sfSymbol: "antenna.radiowaves.left.and.right",
            sensitivityTier: .medium,
            isUserPromptable: true,
            systemNote: nil,
            status: .notDetermined,
            grantLevels: [
                GrantLevel(
                    id: "nearbyInteractions.allow",
                    label: String(localized: "Allow"),
                    description: String(localized: "The app can use the Ultra Wideband chip to measure precise distance and direction to nearby devices running the same app."),
                    dataAccessSummary: String(localized: "Centimeter-accurate distance and directional bearing to nearby iPhones/accessories using UWB ranging. Enables precise indoor spatial awareness between opted-in devices."),
                    isCurrentSelection: false
                ),
                GrantLevel(
                    id: "nearbyInteractions.dontAllow",
                    label: String(localized: "Don't Allow"),
                    description: String(localized: "The app cannot use Ultra Wideband ranging."),
                    dataAccessSummary: String(localized: "No UWB spatial data is accessible."),
                    isCurrentSelection: false
                ),
            ],
            appCapabilities: [
                String(localized: "Measure precise distance and direction to nearby UWB-enabled devices"),
                String(localized: "Enable spatial handoff and proximity-based features"),
                String(localized: "Locate devices with centimeter-level accuracy"),
            ],
            advertiserInferences: [
                String(localized: "Physical proximity data reveals social contacts and co-location patterns"),
                String(localized: "Retail store UWB beacons can track in-store movement precisely"),
                String(localized: "Device co-location reveals household and workplace relationships"),
            ],
            ungatedData: [
                String(localized: "Bluetooth RSSI provides coarse proximity without UWB permission"),
                String(localized: "Wi-Fi signal strength can be used as a proximity proxy"),
                String(localized: "AirDrop discovery (when enabled) reveals nearby Apple devices"),
            ]
        ),

        // MARK: nfc
        PermissionItem(
            id: .nfc,
            name: String(localized: "NFC"),
            category: .deviceConnectivity,
            sfSymbol: "wave.3.right",
            sensitivityTier: .low,
            isUserPromptable: false,
            systemNote: String(localized: "CoreNFC is available to apps but cannot be prompted at runtime. NFC access is declared in the app's entitlements, not controlled by a user permission dialog."),
            status: .notAvailable,
            grantLevels: [
                GrantLevel(
                    id: "nfc.entitlement",
                    label: String(localized: "Entitlement-Based"),
                    description: String(localized: "NFC access is controlled via Apple's app entitlement system, not a user runtime prompt. Apple must approve apps for CoreNFC."),
                    dataAccessSummary: String(localized: "NFC tag scan results including NDEF records, tag identifiers, and any data encoded on the tag. Only possible when user physically taps device to an NFC tag."),
                    isCurrentSelection: false
                ),
            ],
            appCapabilities: [
                String(localized: "Scan NFC tags when user taps device to a tag"),
                String(localized: "Read NDEF records, URLs, and custom data from tags"),
                String(localized: "Cannot scan passively — requires physical tag contact"),
            ],
            advertiserInferences: [
                String(localized: "NFC tag scans reveal specific physical location interactions"),
                String(localized: "Product tags link physical product purchases to digital identity"),
                String(localized: "Transit card scans reveal commute patterns"),
            ],
            ungatedData: [
                String(localized: "Apple Pay NFC payments are processed without app permission but reveal merchant category to banks"),
                String(localized: "NFC-enabled loyalty cards are scanned by retailers regardless of app permissions"),
                String(localized: "NFC tag scan events logged by the tag itself are not controlled by iOS"),
            ]
        ),

        // MARK: faceID
        PermissionItem(
            id: .faceID,
            name: String(localized: "Face ID"),
            category: .identityPrivacy,
            sfSymbol: "faceid",
            sensitivityTier: .medium,
            isUserPromptable: true,
            systemNote: nil,
            status: .notDetermined,
            grantLevels: [
                GrantLevel(
                    id: "faceID.allow",
                    label: String(localized: "Allow"),
                    description: String(localized: "The app can use Face ID to authenticate you. The face scan data never leaves the Secure Enclave."),
                    dataAccessSummary: String(localized: "Authentication result only (success/failure boolean). The actual facial geometry mathematical representation never leaves Apple's Secure Enclave and is not accessible to the app."),
                    isCurrentSelection: false
                ),
                GrantLevel(
                    id: "faceID.dontAllow",
                    label: String(localized: "Don't Allow"),
                    description: String(localized: "The app cannot use Face ID and must fall back to passcode authentication."),
                    dataAccessSummary: String(localized: "No biometric authentication is possible; passcode fallback is still available."),
                    isCurrentSelection: false
                ),
            ],
            appCapabilities: [
                String(localized: "Authenticate you without a password"),
                String(localized: "Unlock sensitive content within the app"),
                String(localized: "Authorize payments or transactions"),
            ],
            advertiserInferences: [
                String(localized: "Biometric data stays on device — minimal direct advertiser value"),
                String(localized: "Authentication use signals high-value account activity"),
            ],
            ungatedData: [
                String(localized: "App authentication frequency is a behavioral signal accessible without biometric data"),
                String(localized: "Account login timing and patterns are logged server-side regardless of Face ID use"),
                String(localized: "The presence of Face ID hardware is detectable without the permission"),
            ]
        ),

        // MARK: tracking
        PermissionItem(
            id: .tracking,
            name: String(localized: "Tracking (ATT)"),
            category: .identityPrivacy,
            sfSymbol: "eye.trianglebadge.exclamationmark",
            sensitivityTier: .high,
            isUserPromptable: true,
            systemNote: nil,
            status: .notDetermined,
            grantLevels: [
                GrantLevel(
                    id: "tracking.allow",
                    label: String(localized: "Allow"),
                    description: String(localized: "The app can access your device's advertising identifier (IDFA) and link your activity across other companies' apps and websites."),
                    dataAccessSummary: String(localized: "IDFA (Identifier for Advertisers): a persistent device-level UUID used to match your identity across apps and ad networks. Enables cross-app behavioral profiling and ad attribution."),
                    isCurrentSelection: false
                ),
                GrantLevel(
                    id: "tracking.askNotToTrack",
                    label: String(localized: "Ask App Not to Track"),
                    description: String(localized: "The app receives a zeroed-out IDFA and is expected not to track you. Compliance is self-reported by the developer."),
                    dataAccessSummary: String(localized: "IDFA returns all zeros. The app can still use probabilistic fingerprinting techniques, though App Store guidelines prohibit this."),
                    isCurrentSelection: false
                ),
            ],
            appCapabilities: [
                String(localized: "Link your identity across apps and websites"),
                String(localized: "Build a persistent behavioral profile"),
                String(localized: "Share your advertising ID with third parties"),
                String(localized: "Target ads based on cross-app activity"),
            ],
            advertiserInferences: [
                String(localized: "Cross-app identity enables a unified behavioral profile"),
                String(localized: "Precise attribution of purchases to ad campaigns"),
                String(localized: "Long-term behavioral modeling across time"),
                String(localized: "Retargeting based on app usage and content consumed"),
            ],
            ungatedData: [
                String(localized: "Probabilistic device fingerprinting (screen size, OS version, timezone, language) works without the IDFA"),
                String(localized: "Email-based identity matching at the app level is not controlled by ATT"),
                String(localized: "First-party behavioral data within the app is collectable regardless of ATT status"),
            ]
        ),

        // MARK: siri
        PermissionItem(
            id: .siri,
            name: String(localized: "Siri & Dictation"),
            category: .identityPrivacy,
            sfSymbol: "mic.badge.plus",
            sensitivityTier: .medium,
            isUserPromptable: true,
            systemNote: nil,
            status: .notDetermined,
            grantLevels: [
                GrantLevel(
                    id: "siri.allow",
                    label: String(localized: "Allow"),
                    description: String(localized: "The app can integrate with Siri, offer Shortcuts, and appear in Siri suggestions."),
                    dataAccessSummary: String(localized: "App usage patterns shared with SiriKit for intent handling. App-defined intents and shortcuts visible in the Shortcuts app. Apple may use anonymized Siri interactions for model improvement."),
                    isCurrentSelection: false
                ),
                GrantLevel(
                    id: "siri.dontAllow",
                    label: String(localized: "Don't Allow"),
                    description: String(localized: "The app cannot integrate with Siri and won't appear in Siri suggestions."),
                    dataAccessSummary: String(localized: "No Siri integration or shortcut donation is possible."),
                    isCurrentSelection: false
                ),
            ],
            appCapabilities: [
                String(localized: "Appear as a Siri shortcut for voice commands"),
                String(localized: "Suggest actions based on usage patterns"),
                String(localized: "Integrate with Shortcuts app"),
            ],
            advertiserInferences: [
                String(localized: "Apple anonymizes Siri data, limiting direct advertiser value"),
                String(localized: "Integration patterns reveal which apps you use most"),
            ],
            ungatedData: [
                String(localized: "App name is identifiable to Apple through Siri system logs regardless of permission"),
                String(localized: "Spotlight indexing of app content happens independently of Siri permission"),
                String(localized: "Usage frequency is observable to Apple through system analytics"),
            ]
        ),

        // MARK: speechRecognition
        PermissionItem(
            id: .speechRecognition,
            name: String(localized: "Speech Recognition"),
            category: .identityPrivacy,
            sfSymbol: "waveform",
            sensitivityTier: .medium,
            isUserPromptable: true,
            systemNote: nil,
            status: .notDetermined,
            grantLevels: [
                GrantLevel(
                    id: "speechRecognition.allow",
                    label: String(localized: "Allow"),
                    description: String(localized: "The app can transcribe spoken audio to text using Apple's on-device and server-side speech recognition."),
                    dataAccessSummary: String(localized: "Audio segments sent to Apple's servers for transcription (unless on-device only mode is specified). Transcribed text returned to the app. Apple may retain audio for model improvement."),
                    isCurrentSelection: false
                ),
                GrantLevel(
                    id: "speechRecognition.dontAllow",
                    label: String(localized: "Don't Allow"),
                    description: String(localized: "The app cannot use speech recognition."),
                    dataAccessSummary: String(localized: "No speech-to-text transcription is possible."),
                    isCurrentSelection: false
                ),
            ],
            appCapabilities: [
                String(localized: "Transcribe speech to text in real time"),
                String(localized: "Process voice commands"),
                String(localized: "Audio may be sent to Apple servers for recognition"),
            ],
            advertiserInferences: [
                String(localized: "Spoken queries reveal search intent and purchasing signals"),
                String(localized: "Voice data processed off-device may be retained"),
            ],
            ungatedData: [
                String(localized: "Microphone permission (separate) is also required and can be used for raw audio"),
                String(localized: "Keyboard dictation uses the same underlying service but is system-controlled"),
                String(localized: "Voice search queries submitted via app text fields are logged server-side"),
            ]
        ),

        // MARK: notifications
        PermissionItem(
            id: .notifications,
            name: String(localized: "Notifications"),
            category: .notificationsBackground,
            sfSymbol: "bell.fill",
            sensitivityTier: .low,
            isUserPromptable: true,
            systemNote: nil,
            status: .notDetermined,
            grantLevels: [
                GrantLevel(
                    id: "notifications.alertSoundBadge",
                    label: String(localized: "Allow (Alert, Sound, Badge)"),
                    description: String(localized: "The app can display banners, play sounds, and update the app badge count."),
                    dataAccessSummary: String(localized: "Full notification delivery including lock screen and Notification Center banners, audible alerts, vibration, and badge count. Notification content may include personalized information."),
                    isCurrentSelection: false
                ),
                GrantLevel(
                    id: "notifications.alertsOnly",
                    label: String(localized: "Alerts Only"),
                    description: String(localized: "The app can display silent banners only, without sounds or badge updates."),
                    dataAccessSummary: String(localized: "Visual notification delivery only. Notification open-rate telemetry is still sent back to the app server."),
                    isCurrentSelection: false
                ),
                GrantLevel(
                    id: "notifications.dontAllow",
                    label: String(localized: "Don't Allow"),
                    description: String(localized: "The app cannot send any notifications."),
                    dataAccessSummary: String(localized: "No notifications are delivered. Silent push notifications (background refresh triggers) may still be received."),
                    isCurrentSelection: false
                ),
            ],
            appCapabilities: [
                String(localized: "Show alerts on your lock screen and notification center"),
                String(localized: "Play sounds and vibrations"),
                String(localized: "Update app badge counts"),
                String(localized: "Send time-sensitive interruptions"),
            ],
            advertiserInferences: [
                String(localized: "Open rates signal engagement and interests"),
                String(localized: "Response timing reveals daily schedule"),
            ],
            ungatedData: [
                String(localized: "Device push token is registered with the app server regardless of notification permission"),
                String(localized: "Silent background push notifications are received even when notifications are disabled"),
                String(localized: "App badge count was visible on home screen as a secondary engagement signal before iOS 16"),
            ]
        ),

        // MARK: backgroundAppRefresh
        PermissionItem(
            id: .backgroundAppRefresh,
            name: String(localized: "Background App Refresh"),
            category: .notificationsBackground,
            sfSymbol: "arrow.clockwise",
            sensitivityTier: .low,
            isUserPromptable: false,
            systemNote: String(localized: "Background App Refresh is controlled globally in iOS Settings > General > Background App Refresh. Apps cannot prompt for it directly."),
            status: .notDetermined,
            grantLevels: [
                GrantLevel(
                    id: "backgroundAppRefresh.enabled",
                    label: String(localized: "Enabled"),
                    description: String(localized: "The app can execute code in the background to refresh content even when not open."),
                    dataAccessSummary: String(localized: "The app's background fetch handler runs periodically. Any data the app normally collects (location, usage, sensor data) may be collected silently during these background sessions."),
                    isCurrentSelection: false
                ),
                GrantLevel(
                    id: "backgroundAppRefresh.disabled",
                    label: String(localized: "Disabled"),
                    description: String(localized: "The app cannot run in the background. It can only refresh content when actively open."),
                    dataAccessSummary: String(localized: "No background execution. Data collection limited to foreground use."),
                    isCurrentSelection: false
                ),
            ],
            appCapabilities: [
                String(localized: "Run code in the background to update content"),
                String(localized: "Collect sensor and location data during background sessions"),
                String(localized: "Download new content before you open the app"),
            ],
            advertiserInferences: [
                String(localized: "Background location updates (if granted) build a continuous movement profile"),
                String(localized: "Background network calls reveal behavioral patterns even when app is not in use"),
                String(localized: "Background refresh frequency indicates how actively an app is tracking you"),
            ],
            ungatedData: [
                String(localized: "Silent push notifications trigger background work regardless of this setting"),
                String(localized: "OS scheduler may wake apps for background tasks at system discretion"),
                String(localized: "VoIP and location apps have separate background execution entitlements unaffected by this toggle"),
            ]
        ),

        // MARK: homeKit
        PermissionItem(
            id: .homeKit,
            name: String(localized: "HomeKit"),
            category: .homeExternal,
            sfSymbol: "house.fill",
            sensitivityTier: .medium,
            isUserPromptable: true,
            systemNote: nil,
            status: .notDetermined,
            grantLevels: [
                GrantLevel(
                    id: "homeKit.allow",
                    label: String(localized: "Allow"),
                    description: String(localized: "The app can access and control your HomeKit-enabled smart home devices, scenes, and automations."),
                    dataAccessSummary: String(localized: "Full HMHome model: accessory names and types, room layout, scene definitions, automation triggers, occupancy state (home/away), lock/unlock states, and camera feeds if applicable."),
                    isCurrentSelection: false
                ),
                GrantLevel(
                    id: "homeKit.dontAllow",
                    label: String(localized: "Don't Allow"),
                    description: String(localized: "The app cannot access your smart home setup."),
                    dataAccessSummary: String(localized: "No HomeKit data is accessible."),
                    isCurrentSelection: false
                ),
            ],
            appCapabilities: [
                String(localized: "Control smart home devices: lights, locks, thermostats, cameras"),
                String(localized: "Read home/away occupancy status"),
                String(localized: "Create and trigger automations"),
                String(localized: "View HomeKit camera streams"),
            ],
            advertiserInferences: [
                String(localized: "Home occupancy patterns reveal detailed daily schedule and sleep times"),
                String(localized: "Smart device inventory reveals household income and lifestyle"),
                String(localized: "Lock/unlock timing reveals when occupants leave and return home"),
            ],
            ungatedData: [
                String(localized: "HomeKit accessory firmware update requests reveal device inventory to manufacturers"),
                String(localized: "Smart home automation logs are stored on Apple's servers via iCloud"),
                String(localized: "Wi-Fi network presence of smart home devices is detectable via local network scanning"),
            ]
        ),

        // MARK: classKit
        PermissionItem(
            id: .classKit,
            name: String(localized: "ClassKit"),
            category: .homeExternal,
            sfSymbol: "graduationcap.fill",
            sensitivityTier: .low,
            isUserPromptable: false,
            systemNote: String(localized: "ClassKit is available only to education apps approved by Apple. It is not user-promptable."),
            status: .notAvailable,
            grantLevels: [
                GrantLevel(
                    id: "classKit.entitlement",
                    label: String(localized: "Entitlement-Based"),
                    description: String(localized: "ClassKit access requires Apple's Education entitlement. It enables apps to report student activity to teachers via Schoolwork."),
                    dataAccessSummary: String(localized: "Student activity data: content completion, quiz scores, time-on-task, and progress through curriculum. Shared with teacher via Apple School Manager."),
                    isCurrentSelection: false
                ),
            ],
            appCapabilities: [
                String(localized: "Report student progress and activity to teachers via Schoolwork"),
                String(localized: "Log time-on-task for educational content"),
                String(localized: "Share curriculum completion data with school administrators"),
            ],
            advertiserInferences: [
                String(localized: "Student education data is legally protected (FERPA/COPPA) and cannot be used for advertising"),
                String(localized: "School enrollment confirms student/minor status"),
                String(localized: "Educational content preferences reveal learning level and subject interests"),
            ],
            ungatedData: [
                String(localized: "iCloud account connected to Managed Apple ID links data to school institution"),
                String(localized: "Screen Time data for educational apps is visible to parent/guardian accounts"),
                String(localized: "App Store education category presence indicates student population"),
            ]
        ),

        // MARK: focusStatus
        PermissionItem(
            id: .focusStatus,
            name: String(localized: "Focus Status"),
            category: .focusSystem,
            sfSymbol: "moon.fill",
            sensitivityTier: .low,
            isUserPromptable: true,
            systemNote: nil,
            status: .notDetermined,
            grantLevels: [
                GrantLevel(
                    id: "focusStatus.allow",
                    label: String(localized: "Allow"),
                    description: String(localized: "The app can see whether you have a Focus mode enabled (e.g., Do Not Disturb, Sleep, Work) so it can adapt its behavior."),
                    dataAccessSummary: String(localized: "Boolean isFocused flag only. The app learns whether a Focus is active but not which specific Focus (e.g., Work vs. Personal) unless you share status in Focus settings."),
                    isCurrentSelection: false
                ),
                GrantLevel(
                    id: "focusStatus.dontAllow",
                    label: String(localized: "Don't Allow"),
                    description: String(localized: "The app cannot determine whether you have a Focus mode active."),
                    dataAccessSummary: String(localized: "Focus state is not accessible to the app."),
                    isCurrentSelection: false
                ),
            ],
            appCapabilities: [
                String(localized: "Detect whether a Focus mode (Do Not Disturb, Sleep, Work) is currently active"),
                String(localized: "Adapt messaging behavior based on your availability status"),
                String(localized: "Show your Focus status to contacts in messaging apps"),
            ],
            advertiserInferences: [
                String(localized: "Focus timing reveals sleep schedule and work hours"),
                String(localized: "Frequent Focus activation signals stress or concentration patterns"),
                String(localized: "Focus mode changes correlate with context switches useful for behavioral profiling"),
            ],
            ungatedData: [
                String(localized: "Message delivery receipts implicitly reveal Focus state to senders"),
                String(localized: "App interaction timing correlates with Focus periods without explicit access"),
                String(localized: "Screen Time data includes Focus duration accessible to Screen Time API"),
            ]
        ),
    ]
}
