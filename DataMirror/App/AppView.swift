import SwiftUI
import ComposableArchitecture

struct AppView: View {
    @Bindable var store: StoreOf<AppFeature>
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var columnVisibility: NavigationSplitViewVisibility = .automatic

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebarContent
                .navigationTitle("DataMirror")
        } detail: {
            detailContent
        }
        .navigationSplitViewStyle(.balanced)
        .tint(Color.accentColor)
        .onAppear { store.send(.onAppear) }
        .fullScreenCover(isPresented: Binding(
            get: { !store.hasSeenPrimer },
            set: { _ in }
        )) {
            PrimerView(store: store.scope(state: \.primer, action: \.primer))
        }
    }

    // MARK: - Sidebar

    @ViewBuilder
    private var sidebarContent: some View {
        if sizeClass == .regular {
            ScrollView {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 140))],
                    spacing: 16
                ) {
                    ForEach(AppFeature.Section.allCases) { section in
                        SectionCell(
                            section: section,
                            isSelected: store.selectedSection == section
                        )
                        .onTapGesture {
                            store.send(.sectionSelected(section))
                        }
                        .accessibilityLabel(
                            "\(section.title) — \(section.subtitle)"
                        )
                    }
                }
                .padding()
            }
        } else {
            List(AppFeature.Section.allCases, selection: $store.selectedSection.sending(\.sectionSelected)) { section in
                Label(section.title, systemImage: section.systemImage)
                    .tag(section)
                    .accessibilityLabel(
                        "\(section.title) — \(section.subtitle)"
                    )
            }
        }
    }

    // MARK: - Detail

    @ViewBuilder
    private var detailContent: some View {
        if let section = store.selectedSection {
            switch section {
            case .dashboard:
                DashboardView(store: store.scope(state: \.dashboard, action: \.dashboard))
            case .permissions:
                PermissionsView(store: store.scope(state: \.permissions, action: \.permissions))
            case .inferred:
                InferredView(store: store.scope(state: \.inferred, action: \.inferred))
            case .history:
                HistoryView(store: store.scope(state: \.history, action: \.history))
            case .about:
                AboutView(store: store.scope(state: \.about, action: \.about))
            }
        } else {
            ContentUnavailableView(
                String(localized: "Select a Section"),
                systemImage: "eye",
                description: Text(String(localized: "Choose a section from the sidebar"))
            )
        }
    }
}

// MARK: - Section Grid Cell (iPad)

private struct SectionCell: View {
    let section: AppFeature.Section
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: section.systemImage)
                .font(.system(size: 28))
                .foregroundStyle(isSelected ? Color.accentColor : .secondary)

            Text(section.title)
                .font(.headline)
                .foregroundStyle(isSelected ? Color.accentColor : .primary)

            Text(section.subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? Color.accentColor.opacity(0.1) : Color(.secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(isSelected ? Color.accentColor : .clear, lineWidth: 2)
        )
    }
}

#Preview {
    AppView(
        store: Store(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.sensorClient = .testValue
            $0.permissionClient = .testValue
            $0.userDefaults = .testValue
            $0.sharedDefaults = .testValue
        }
    )
}
