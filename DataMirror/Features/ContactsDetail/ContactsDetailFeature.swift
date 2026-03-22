import ComposableArchitecture
import Foundation
import os

private nonisolated let logger = Logger(subsystem: "com.datamirror", category: "ContactsDetail")

@Reducer
struct ContactsDetailFeature {
    @ObservableState
    struct State: Equatable {
        var contacts: IdentifiedArrayOf<ContactRecord> = []
        var isLoading: Bool = false
        var searchQuery: String = ""

        var filteredContacts: IdentifiedArrayOf<ContactRecord> {
            guard !searchQuery.isEmpty else { return contacts }
            return IdentifiedArrayOf(
                uniqueElements: contacts.filter { contact in
                    contact.displayName.localizedCaseInsensitiveContains(searchQuery)
                    || contact.phoneNumbers.contains { $0.value.contains(searchQuery) }
                    || contact.emailAddresses.contains { $0.value.localizedCaseInsensitiveContains(searchQuery) }
                }
            )
        }
    }

    enum Action {
        case onAppear
        case contactsLoaded([ContactRecord])
        case searchQueryChanged(String)
        case loadFailed
    }

    @Dependency(\.permissionClient) var permissionClient

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                guard state.contacts.isEmpty else { return .none }
                state.isLoading = true
                return .run { send in
                    do {
                        let records = try await permissionClient.fetchContacts()
                        await send(.contactsLoaded(records))
                    } catch {
                        logger.error("Failed to load contacts: \(error.localizedDescription)")
                        await send(.loadFailed)
                    }
                }
            case let .contactsLoaded(records):
                state.isLoading = false
                state.contacts = IdentifiedArrayOf(uniqueElements: records)
                return .none
            case let .searchQueryChanged(query):
                state.searchQuery = query
                return .none
            case .loadFailed:
                state.isLoading = false
                return .none
            }
        }
    }
}
