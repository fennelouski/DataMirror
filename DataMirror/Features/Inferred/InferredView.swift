import SwiftUI
import ComposableArchitecture

struct InferredView: View {
    @Bindable var store: StoreOf<InferredFeature>
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            List {
                Section {
                    summaryCard
                }
                .listRowBackground(Color.clear)

                if !store.behavioralInferences.isEmpty {
                    Section(String(localized: "Right Now")) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(store.behavioralInferences) { inference in
                                    BehavioralCardView(inference: inference) {
                                        store.send(.inferenceTapped(inference))
                                    }
                                }
                            }
                            .padding(.horizontal, 4)
                        }
                        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                    }
                }

                ForEach(store.groupedStructural, id: \.0) { category, inferences in
                    Section(category.displayName) {
                        ForEach(inferences) { inference in
                            InferenceCardView(inference: inference) {
                                store.send(.inferenceTapped(inference))
                            }
                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                            .listRowBackground(Color.clear)
                        }
                    }
                }

                if store.isLoading && store.structuralInferences.isEmpty {
                    Section {
                        HStack { Spacer(); ProgressView().padding(); Spacer() }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(String(localized: "Inferred"))
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { store.send(.aboutTapped) } label: {
                        Image(systemName: "info.circle")
                            .accessibilityLabel(String(localized: "About these inferences"))
                    }
                }
            }
            .onAppear { store.send(.onAppear) }
            .onChange(of: scenePhase) { _, newPhase in
                store.send(.scenePhaseChanged(newPhase == .active))
            }
            .sheet(isPresented: Binding(
                get: { store.showAboutSheet },
                set: { newValue in if !newValue { store.send(.aboutDismissed) } }
            )) {
                aboutSheet
            }
            .navigationDestination(item: Binding(
                get: { store.selectedInference },
                set: { newValue in if newValue == nil { store.send(.inferenceDetailDismissed) } }
            )) { inference in
                InferenceDetailView(inference: inference)
            }
        }
    }

    @ViewBuilder
    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .font(.title2)
                    .foregroundStyle(Color.accentColor)
                    .accessibilityHidden(true)
                Text(String(localized: "What Can Be Inferred"))
                    .font(.headline)
            }
            Text(String(localized: "Based on your current permissions, DataMirror can infer \(store.meaningfulInferenceCount) facts about you with medium or higher confidence."))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private var aboutSheet: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(String(localized: "DataMirror computes these inferences entirely on your device. Nothing leaves your phone."))
                        Text(String(localized: "Confidence levels reflect how certain the inference is based on available signals — not whether it is definitively true about you."))
                    }
                }
                Section(String(localized: "Confidence Levels")) {
                    ForEach(Confidence.allCases, id: \.rawValue) { level in
                        HStack {
                            ConfidenceBadgeView(confidence: level)
                            Spacer()
                            Text(level.accuracyRange)
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Section {
                    Text(String(localized: "Real data brokers use these same signal types, combined with data purchased from hundreds of other sources, to build profiles with much higher accuracy than what you see here."))
                    Text(String(localized: "The purpose of this feature is to show you what is possible from device data alone — not to profile you."))
                        .bold()
                }
                Section {
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Label(String(localized: "Open Privacy Settings"), systemImage: "hand.raised.fill")
                    }
                }
            }
            .navigationTitle(String(localized: "About These Inferences"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Done")) { store.send(.aboutDismissed) }
                }
            }
        }
    }
}

#Preview {
    InferredView(
        store: Store(initialState: InferredFeature.State()) {
            InferredFeature()
        } withDependencies: {
            $0.inferenceClient = .testValue
        }
    )
}
