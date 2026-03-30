import SwiftUI
import Charts
import ComposableArchitecture

struct HistoryView: View {
    let store: StoreOf<HistoryFeature>
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            Group {
                if store.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if store.snapshots.isEmpty {
                    emptyState
                } else {
                    historyContent
                }
            }
            .navigationTitle(String(localized: "History"))
            .background(Color(.systemGroupedBackground))
        }
        .onAppear { store.send(.onAppear) }
        .onChange(of: scenePhase) { _, newPhase in
            store.send(.scenePhaseChanged(newPhase))
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text(String(localized: "No history yet. Snapshots of this overview are saved as you use the app."))
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var historyContent: some View {
        ScrollView {
            VStack(spacing: 16) {
                scoreChart
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))

                snapshotList
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
            }
            .padding()
        }
    }

    @ViewBuilder
    private var scoreChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "Permission weight over time"))
                .font(.headline)
                .accessibilityAddTraits(.isHeader)

            Chart {
                RectangleMark(
                    xStart: nil, xEnd: nil,
                    yStart: .value("", 0), yEnd: .value("", 100)
                )
                .foregroundStyle(Color(.systemGray5).opacity(0.35))

                ForEach(store.snapshots) { snapshot in
                    LineMark(
                        x: .value("Date", snapshot.date),
                        y: .value("Weight", snapshot.total)
                    )
                    .foregroundStyle(Color.accentColor)
                    .interpolationMethod(.catmullRom)

                    PointMark(
                        x: .value("Date", snapshot.date),
                        y: .value("Weight", snapshot.total)
                    )
                    .foregroundStyle(Color.accentColor)
                    .symbolSize(store.snapshots.count == 1 ? 40 : 15)
                }
            }
            .chartYScale(domain: 0...100)
            .chartYAxis {
                AxisMarks(values: [0, 50, 100])
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                }
            }
            .frame(height: 200)
            .accessibilityLabel(String(localized: "Permission overview chart showing \(store.snapshots.count) data points over time"))
        }
    }

    @ViewBuilder
    private var snapshotList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "Recent Snapshots"))
                .font(.headline)
                .accessibilityAddTraits(.isHeader)

            let reversed = Array(store.snapshots.reversed())
            ForEach(Array(reversed.enumerated()), id: \.element.id) { index, snapshot in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(snapshot.date, style: .date)
                            .font(.subheadline)
                        Text(snapshot.date, style: .time)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("\(snapshot.total)")
                        .font(.title3.bold().monospacedDigit())
                        .foregroundStyle(Color.accentColor)

                    if index < reversed.count - 1 {
                        let previous = reversed[index + 1]
                        let delta = snapshot.total - previous.total
                        deltaView(delta)
                    }
                }
                .padding(.vertical, 4)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(String(localized: "Relative weight \(snapshot.total) on \(snapshot.date.formatted(date: .abbreviated, time: .shortened))"))

                if index < reversed.count - 1 {
                    Divider()
                }
            }
        }
    }

    @ViewBuilder
    private func deltaView(_ delta: Int) -> some View {
        if delta > 0 {
            Text("▲ \(delta)")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .frame(width: 50, alignment: .trailing)
        } else if delta < 0 {
            Text("▼ \(abs(delta))")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .frame(width: 50, alignment: .trailing)
        } else {
            Text("—")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 50, alignment: .trailing)
        }
    }
}

#Preview {
    HistoryView(
        store: Store(initialState: HistoryFeature.State()) {
            HistoryFeature()
        } withDependencies: {
            $0.sharedDefaults = .testValue
        }
    )
}
