import Foundation

struct LabeledValue: Equatable, Identifiable, Sendable {
    let id: String
    let label: String
    let value: String
}

struct PostalAddressRecord: Equatable, Identifiable, Sendable {
    let id: String
    let label: String
    let street: String
    let city: String
    let state: String
    let postalCode: String
    let country: String

    var formatted: String {
        [street, city, state, postalCode, country]
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }
}

struct ContactRecord: Equatable, Identifiable, Sendable {
    let id: String
    let givenName: String
    let familyName: String
    let organizationName: String
    let jobTitle: String
    let phoneNumbers: [LabeledValue]
    let emailAddresses: [LabeledValue]
    let postalAddresses: [PostalAddressRecord]
    let birthday: DateComponents?
    let note: String
    let socialProfiles: [LabeledValue]
    let urlAddresses: [LabeledValue]
    let relations: [LabeledValue]
    let instantMessageAddresses: [LabeledValue]
    let thumbnail: Data?
    let creationDate: Date?
    let modificationDate: Date?

    var fullName: String {
        [givenName, familyName].filter { !$0.isEmpty }.joined(separator: " ")
    }

    var displayName: String {
        let name = fullName
        return name.isEmpty ? organizationName : name
    }
}
