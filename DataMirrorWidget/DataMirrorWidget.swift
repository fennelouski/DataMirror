// SETUP REQUIRED:
// 1. In Xcode, select File → New → Target → Widget Extension, name it "DataMirrorWidget"
// 2. Replace the generated Swift file with this file
// 3. In Xcode, select the DataMirror target → Signing & Capabilities → + Capability → App Groups
// 4. Add group ID: group.com.datamirror
// 5. Repeat for the DataMirrorWidget target
// 6. Both targets must share the same group ID exactly

import WidgetKit
import SwiftUI

// MARK: - Timeline Provider

struct DataMirrorProvider: TimelineProvider {
    private let defaults = UserDefaults(suiteName: "group.com.datamirror") ?? .standard
    private let scoreKey = "datamirror.exposurescore"

    func placeholder(in context: Context) -> ScoreEntry {
        ScoreEntry(date: Date(), score: 42, locationScore: 15, identityScore: 10, behavioralScore: 8, deviceScore: 9)
    }

    func getSnapshot(in context: Context, completion: @escaping (ScoreEntry) -> Void) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ScoreEntry>) -> Void) {
        let entry = currentEntry()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date()
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func currentEntry() -> ScoreEntry {
        let score = defaults.integer(forKey: scoreKey)
        // Sub-scores are estimated from the total for widget display
        let location = min(score * 40 / max(score, 1), 40)
        let identity = min(score * 30 / max(score, 1), 30)
        let behavioral = min(score * 20 / max(score, 1), 20)
        let device = max(score - location - identity - behavioral, 0)
        return ScoreEntry(
            date: Date(),
            score: score,
            locationScore: location,
            identityScore: identity,
            behavioralScore: behavioral,
            deviceScore: device
        )
    }
}

// MARK: - Entry

struct ScoreEntry: TimelineEntry {
    let date: Date
    let score: Int
    let locationScore: Int
    let identityScore: Int
    let behavioralScore: Int
    let deviceScore: Int
}

// MARK: - Score Color

private func scoreColor(_ score: Int) -> Color {
    switch score {
    case 0..<30: .green
    case 30..<60: .yellow
    default: .red
    }
}

// MARK: - Small Widget

struct SmallWidgetView: View {
    let entry: ScoreEntry

    var body: some View {
        VStack(spacing: 4) {
            Text("\(entry.score)")
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundStyle(scoreColor(entry.score))
                .monospacedDigit()
            Text("Exposure Score")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .containerBackground(for: .widget) {
            Color(.systemBackground)
        }
    }
}

// MARK: - Medium Widget

struct MediumWidgetView: View {
    let entry: ScoreEntry

    var body: some View {
        HStack(spacing: 20) {
            VStack(spacing: 4) {
                Text("\(entry.score)")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundStyle(scoreColor(entry.score))
                    .monospacedDigit()
                Text("Exposure Score")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: 6) {
                SubScorePill(label: "Location", value: entry.locationScore, color: .blue)
                SubScorePill(label: "Identity", value: entry.identityScore, color: .purple)
                SubScorePill(label: "Behavioral", value: entry.behavioralScore, color: .orange)
                SubScorePill(label: "Device", value: entry.deviceScore, color: .teal)
            }
            .frame(maxWidth: .infinity)
        }
        .containerBackground(for: .widget) {
            Color(.systemBackground)
        }
    }
}

private struct SubScorePill: View {
    let label: String
    let value: Int
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Spacer()
            Text("\(value)")
                .font(.caption2.bold())
                .foregroundStyle(color)
                .monospacedDigit()
        }
    }
}

// MARK: - Accessory Circular

struct AccessoryCircularView: View {
    let entry: ScoreEntry

    var body: some View {
        Gauge(value: Double(entry.score), in: 0...100) {
            Text("\(entry.score)")
                .font(.system(.body, design: .rounded, weight: .bold))
        }
        .gaugeStyle(.accessoryCircular)
    }
}

// MARK: - Accessory Rectangular

struct AccessoryRectangularView: View {
    let entry: ScoreEntry

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("DataMirror")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(summaryString)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(entry.score)")
                .font(.system(.title, design: .rounded, weight: .bold))
        }
    }

    private var summaryString: String {
        switch entry.score {
        case 0..<30: "Low exposure"
        case 30..<60: "Moderate"
        default: "High exposure"
        }
    }
}

// MARK: - Widget

struct DataMirrorWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: ScoreEntry

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        case .accessoryCircular:
            AccessoryCircularView(entry: entry)
        case .accessoryRectangular:
            AccessoryRectangularView(entry: entry)
        default:
            SmallWidgetView(entry: entry)
        }
    }
}

struct DataMirrorWidget: Widget {
    let kind = "DataMirrorWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DataMirrorProvider()) { entry in
            DataMirrorWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Exposure Score")
        .description("Shows your current data exposure score.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular])
    }
}

// MARK: - Widget Entry Point

@main
struct DataMirrorWidgetBundle: WidgetBundle {
    var body: some Widget {
        DataMirrorWidget()
    }
}

// MARK: - Previews

#Preview("Small", as: .systemSmall) {
    DataMirrorWidget()
} timeline: {
    ScoreEntry(date: .now, score: 42, locationScore: 15, identityScore: 10, behavioralScore: 8, deviceScore: 9)
}

#Preview("Medium", as: .systemMedium) {
    DataMirrorWidget()
} timeline: {
    ScoreEntry(date: .now, score: 42, locationScore: 15, identityScore: 10, behavioralScore: 8, deviceScore: 9)
}
