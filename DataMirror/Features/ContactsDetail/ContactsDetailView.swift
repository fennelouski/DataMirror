import SwiftUI
import ComposableArchitecture

struct ContactsDetailView: View {
    @Bindable var store: StoreOf<ContactsDetailFeature>

    var body: some View {
        Group {
            if store.isLoading {
                ProgressView(String(localized: "Loading Contacts…"))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                contactList
            }
        }
        .navigationTitle(String(localized: "Your Contacts (\(store.contacts.count))"))
        .searchable(
            text: Binding(
                get: { store.searchQuery },
                set: { store.send(.searchQueryChanged($0)) }
            ),
            prompt: String(localized: "Search by name, phone, or email")
        )
        .onAppear { store.send(.onAppear) }
    }

    private var contactList: some View {
        List(store.filteredContacts) { contact in
            NavigationLink(destination: ContactRecordDetailView(contact: contact)) {
                ContactRowView(contact: contact)
            }
        }
    }
}

// MARK: - Contact Row

private struct ContactRowView: View {
    let contact: ContactRecord

    var body: some View {
        HStack(spacing: 12) {
            ContactAvatarView(contact: contact, size: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(contact.displayName)
                    .font(.body.bold())
                if !contact.organizationName.isEmpty {
                    Text(contact.organizationName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let phone = contact.phoneNumbers.first?.value {
                    Text(phone)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let email = contact.emailAddresses.first?.value {
                    Text(email)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
        .accessibilityLabel(contact.displayName)
        .accessibilityHint(String(localized: "Double tap to view contact details"))
    }
}

// MARK: - Contact Avatar

private struct ContactAvatarView: View {
    let contact: ContactRecord
    let size: CGFloat

    var body: some View {
        if let data = contact.thumbnail, let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(Circle())
        } else {
            Circle()
                .fill(avatarColor)
                .frame(width: size, height: size)
                .overlay {
                    Text(initials)
                        .font(.system(size: size * 0.35, weight: .semibold))
                        .foregroundStyle(.white)
                }
        }
    }

    private var initials: String {
        let given = contact.givenName.prefix(1)
        let family = contact.familyName.prefix(1)
        let combined = "\(given)\(family)"
        return combined.isEmpty ? String(contact.organizationName.prefix(1).uppercased()) : combined.uppercased()
    }

    private var avatarColor: Color {
        let colors: [Color] = [.blue, .green, .orange, .purple, .pink, .teal, .indigo, .red]
        let hash = abs(contact.displayName.hashValue)
        return colors[hash % colors.count]
    }
}

// MARK: - Contact Record Detail View

struct ContactRecordDetailView: View {
    let contact: ContactRecord

    var body: some View {
        Form {
            Section {
                DataMirrorPrivacyBanner(
                    text: String(localized: "This is what any app with Contacts access can read about this person.")
                )
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            Section(String(localized: "Basic Info")) {
                if !contact.displayName.isEmpty {
                    LabeledContent(String(localized: "Name"), value: contact.displayName)
                }
                if !contact.organizationName.isEmpty {
                    LabeledContent(String(localized: "Organization"), value: contact.organizationName)
                }
                if !contact.jobTitle.isEmpty {
                    LabeledContent(String(localized: "Job Title"), value: contact.jobTitle)
                }
            }

            if !contact.phoneNumbers.isEmpty {
                Section(String(localized: "Phone Numbers")) {
                    ForEach(contact.phoneNumbers) { phone in
                        LabeledContent(phone.label, value: phone.value)
                    }
                }
            }

            if !contact.emailAddresses.isEmpty {
                Section(String(localized: "Email Addresses")) {
                    ForEach(contact.emailAddresses) { email in
                        LabeledContent(email.label, value: email.value)
                    }
                }
            }

            if !contact.postalAddresses.isEmpty {
                Section(String(localized: "Postal Addresses")) {
                    ForEach(contact.postalAddresses) { addr in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(addr.label)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(addr.formatted)
                                .font(.body)
                        }
                    }
                }
            }

            if let birthday = contact.birthday,
               let date = Calendar.current.date(from: birthday) {
                Section(String(localized: "Birthday")) {
                    Text(date, style: .date)
                }
            }

            if !contact.relations.isEmpty {
                Section(String(localized: "Relationships")) {
                    ForEach(contact.relations) { rel in
                        LabeledContent(rel.label, value: rel.value)
                    }
                }
            }

            if !contact.socialProfiles.isEmpty {
                Section(String(localized: "Social Profiles")) {
                    ForEach(contact.socialProfiles) { profile in
                        LabeledContent(profile.label, value: profile.value)
                    }
                }
            }

            if !contact.urlAddresses.isEmpty {
                Section(String(localized: "Web URLs")) {
                    ForEach(contact.urlAddresses) { url in
                        LabeledContent(url.label, value: url.value)
                    }
                }
            }

            if !contact.instantMessageAddresses.isEmpty {
                Section(String(localized: "Instant Message")) {
                    ForEach(contact.instantMessageAddresses) { im in
                        LabeledContent(im.label, value: im.value)
                    }
                }
            }

            if !contact.note.isEmpty {
                Section(String(localized: "Notes")) {
                    Text(contact.note)
                }
            }

            Section(String(localized: "Metadata")) {
                if let created = contact.creationDate {
                    LabeledContent(
                        String(localized: "Created"),
                        value: created.formatted(date: .abbreviated, time: .shortened)
                    )
                }
                if let modified = contact.modificationDate {
                    LabeledContent(
                        String(localized: "Modified"),
                        value: modified.formatted(date: .abbreviated, time: .shortened)
                    )
                }
            }
        }
        .navigationTitle(contact.displayName)
        .navigationBarTitleDisplayMode(.inline)
    }
}
