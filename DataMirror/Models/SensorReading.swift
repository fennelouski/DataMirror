import Foundation

struct SensorReading: Equatable, Identifiable, Sendable {
    let id: String
    let label: String
    let value: String
    let unit: String?
    let lastUpdated: Date
    let requiresPermission: Bool
    let permissionStatus: PermissionStatus
}

struct SensorGroup: Equatable, Identifiable, Sendable {
    let id: String
    let name: String
    let sfSymbol: String
    var readings: [SensorReading]
}
