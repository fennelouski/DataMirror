import SwiftUI
import ComposableArchitecture

struct AppView: View {
    @Bindable var store: StoreOf<AppFeature>

    var body: some View {
        TabView(selection: $store.selectedTab.sending(\.tabSelected)) {
            DashboardView(store: store.scope(state: \.dashboard, action: \.dashboard))
                .tabItem {
                    Label(String(localized: "Dashboard"), systemImage: "waveform")
                }
                .tag(AppFeature.Tab.dashboard)
                .accessibilityLabel(String(localized: "Dashboard — live sensor readings"))

            PermissionsView(store: store.scope(state: \.permissions, action: \.permissions))
                .tabItem {
                    Label(String(localized: "Permissions"), systemImage: "lock.shield")
                }
                .tag(AppFeature.Tab.permissions)
                .accessibilityLabel(String(localized: "Permissions — manage app access"))

            InferredView(store: store.scope(state: \.inferred, action: \.inferred))
                .tabItem {
                    Label(String(localized: "Inferred"), systemImage: "brain.head.profile")
                }
                .tag(AppFeature.Tab.inferred)
                .accessibilityLabel(String(localized: "Inferred — what can be deduced about you"))

            HistoryView(store: store.scope(state: \.history, action: \.history))
                .tabItem {
                    Label(String(localized: "History"), systemImage: "chart.line.uptrend.xyaxis")
                }
                .tag(AppFeature.Tab.history)
                .accessibilityLabel(String(localized: "History — exposure score over time"))

            AboutView(store: store.scope(state: \.about, action: \.about))
                .tabItem {
                    Label(String(localized: "About"), systemImage: "info.circle")
                }
                .tag(AppFeature.Tab.about)
                .accessibilityLabel(String(localized: "About DataMirror"))
        }
        .tint(Color.accentColor)
        .onAppear { store.send(.onAppear) }
        .fullScreenCover(isPresented: Binding(
            get: { !store.hasSeenPrimer },
            set: { _ in }
        )) {
            PrimerView(store: store.scope(state: \.primer, action: \.primer))
        }
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
