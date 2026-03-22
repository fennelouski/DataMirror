import Foundation

/// A single piece of data that contributed to an inference.
struct Evidence: Equatable, Identifiable, Sendable {
    let id: UUID
    let permissionType: PermissionType
    let description: String
    let rawValue: String
    let weight: Double
}
