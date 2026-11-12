import ComposableArchitecture
import SwiftUI

/// What an external display shows instead of a mirror of the phone: the screen
/// the user is on, re-flowed into columns that fill the display's own shape.
///
/// Read-only by design. It renders `AppFeature.State` and never sends an
/// action, so it cannot drift from the phone or start work the phone didn't.
struct ExternalDisplayView: View {
    let store: StoreOf<AppFeature>
    @Environment(\.displayScale) private var displayScale

    /// Every display is laid out as if it were this many points tall, then
    /// scaled to fit, so text takes the same share of a projector and a 4K TV.
    private static let logicalHeight: CGFloat = 540

    var body: some View {
        GeometryReader { proxy in
            let scale = max(proxy.size.height, 1) / Self.logicalHeight
            screen
                .padding(24)
                .frame(
                    width: proxy.size.width / scale,
                    height: Self.logicalHeight,
                    alignment: .topLeading
                )
                // Rasterize at the scaled-up resolution so text stays sharp.
                .environment(\.displayScale, displayScale * scale)
                .scaleEffect(scale)
                .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        // The room reads this, not the phone's owner: ignore their text size.
        .dynamicTypeSize(.large)
    }

    @ViewBuilder
    private var screen: some View {
        if !store.hasSeenPrimer {
            PrimerScreen()
        } else {
            switch store.selectedSection {
            case .dashboard:
                DashboardScreen(
                    score: store.dashboard.score,
                    permissions: Array(store.dashboard.permissions),
                    groups: Array(store.dashboard.sensorGroups),
                    selectedGroupID: store.dashboard.selectedSensorGroupID
                )
            case .permissions:
                switch store.permissions.path.last {
                case let .permissionDetail(detail):
                    PermissionDetailScreen(item: detail.item, openLevel: detail.grantLevelSheet?.level)
                case let .contactsDetail(contacts):
                    ContactsScreen(contacts: Array(contacts.filteredContacts), query: contacts.searchQuery)
                case let .photosGallery(gallery):
                    PhotosScreen(assets: Array(gallery.assets))
                case nil:
                    PermissionsScreen(permissions: Array(store.permissions.permissions))
                }
            case .inferred:
                if let inference = store.inferred.selectedInference {
                    InferenceDetailScreen(inference: inference)
                } else {
                    InferredScreen(
                        inferences: store.inferred.behavioralInferences + store.inferred.structuralInferences,
                        meaningfulCount: store.inferred.meaningfulInferenceCount
                    )
                }
            case .history:
                HistoryScreen(snapshots: store.history.snapshots)
            case .about:
                AboutScreen(version: store.about.appVersion)
            case nil:
                Screen(title: String(localized: "Select a Section"), systemImage: "eye") {
                    ColumnFlow {
                        ForEach(AppFeature.Section.allCases) { section in
                            SectionCell(section: section, isSelected: false)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Layout

/// Flows cards top to bottom into equal columns, using as few columns as will
/// hold everything. The column count follows the display's shape, so a 4:3
/// projector gets two or three wide columns and a 16:9 TV three or four.
///
/// `nonisolated` because SwiftUI may run layout off the main thread.
nonisolated struct ColumnFlow: Layout {
    var spacing: CGFloat = 12
    /// Wider than this and lines get too long. The narrow end is a last resort
    /// for dense screens: the fewest columns that fit always win.
    var columnWidth: ClosedRange<CGFloat> = 160...380

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        proposal.replacingUnspecifiedDimensions()
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let width = bounds.width
        guard width.isFinite, width > 0 else { return }
        let fewest = max(1, Int((width / columnWidth.upperBound).rounded(.up)))
        let most = max(fewest, Int(width / columnWidth.lowerBound))

        var column: CGFloat = 0
        var heights: [CGFloat] = []
        var columns: [[Int]] = []
        for count in fewest...most {
            column = (width - spacing * CGFloat(count - 1)) / CGFloat(count)
            heights = subviews.map { $0.sizeThatFits(ProposedViewSize(width: column, height: nil)).height }
            columns = Self.balance(heights, into: count, spacing: spacing)
            let tallest = columns.map { Self.height(of: $0, heights, spacing) }.max() ?? 0
            if tallest <= bounds.height { break }
            // ponytail: if even the most columns overflow, the bottom is cut off.
            // Raise `logicalHeight` (smaller text, more room) if a screen ever does.
        }

        // Few cards can leave columns unused: centre the block rather than
        // pinning it to the leading edge.
        let used = CGFloat(columns.count) * (column + spacing) - spacing
        let leading = bounds.minX + max(0, (width - used) / 2)
        for (index, members) in columns.enumerated() {
            var y = bounds.minY
            for member in members {
                subviews[member].place(
                    at: CGPoint(x: leading + CGFloat(index) * (column + spacing), y: y),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(width: column, height: heights[member])
                )
                y += heights[member] + spacing
            }
        }
    }

    /// Splits `heights` into at most `count` columns of similar height, keeping
    /// reading order: a card starts the next column once its midpoint would
    /// pass the average column height.
    static func balance(_ heights: [CGFloat], into count: Int, spacing: CGFloat) -> [[Int]] {
        let total = heights.reduce(0, +) + spacing * CGFloat(max(heights.count - 1, 0))
        let target = total / CGFloat(max(count, 1))
        var columns: [[Int]] = [[]]
        var filled: CGFloat = 0
        for (index, height) in heights.enumerated() {
            if !columns[columns.count - 1].isEmpty, columns.count < count, filled + height / 2 > target {
                columns.append([])
                filled = 0
            }
            columns[columns.count - 1].append(index)
            filled += height + spacing
        }
        return columns
    }

    private static func height(of members: [Int], _ heights: [CGFloat], _ spacing: CGFloat) -> CGFloat {
        members.reduce(-spacing) { $0 + heights[$1] + spacing }
    }
}

/// A grid of equal cells showing exactly as many items as fit: the second
/// screen cannot scroll, so a partial row would only be cut off.
private struct FittedGrid<Item: Identifiable, Cell: View>: View {
    let items: [Item]
    let minCellWidth: CGFloat
    /// `nil` makes the cells square.
    var cellHeight: CGFloat?
    var spacing: CGFloat = 8
    @ViewBuilder var cell: (Item) -> Cell

    var body: some View {
        GeometryReader { proxy in
            let columns = max(1, Int((proxy.size.width + spacing) / (minCellWidth + spacing)))
            let width = (proxy.size.width - spacing * CGFloat(columns - 1)) / CGFloat(columns)
            let height = cellHeight ?? width
            let rows = max(1, Int((proxy.size.height + spacing) / (height + spacing)))
            LazyVGrid(
                columns: Array(repeating: GridItem(.fixed(width), spacing: spacing), count: columns),
                alignment: .leading,
                spacing: spacing
            ) {
                ForEach(items.prefix(columns * rows)) { item in
                    cell(item).frame(width: width, height: height)
                }
            }
        }
    }
}

// MARK: - Chrome

private struct Screen<Content: View>: View {
    let title: String
    let systemImage: String
    var detail: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Label(title, systemImage: systemImage)
                    .font(.title2.bold())
                if let detail {
                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(String(localized: "DataMirror"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}

private struct Card<Content: View>: View {
    var title: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
            }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct Bullets: View {
    let items: [String]
    let systemImage: String

    var body: some View {
        ForEach(items, id: \.self) { item in
            Label(item, systemImage: systemImage)
                .font(.subheadline)
        }
    }
}

// MARK: - Primer

private struct PrimerScreen: View {
    var body: some View {
        HStack(spacing: 48) {
            VStack(spacing: 12) {
                Image("Icon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 96, height: 96)
                Text(String(localized: "DataMirror"))
                    .font(.largeTitle.bold())
                Text(String(localized: "See exactly what your iPhone shares"))
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: 320)

            VStack(alignment: .leading, spacing: 20) {
                ForEach(PrimerView.features, id: \.symbol) { feature in
                    HStack(spacing: 16) {
                        Image(systemName: feature.symbol)
                            .font(.title2)
                            .foregroundStyle(Color.accentColor)
                            .frame(width: 36)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(feature.title).font(.headline)
                            Text(feature.subtitle).font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .frame(maxWidth: 420, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Dashboard

private struct DashboardScreen: View {
    let score: ExposureScore
    let permissions: [PermissionItem]
    let groups: [SensorGroup]
    let selectedGroupID: String?

    var body: some View {
        if let group = groups.first(where: { $0.id == selectedGroupID }) {
            Screen(
                title: group.name,
                systemImage: group.sfSymbol,
                detail: String(localized: "\(group.readings.count) readings")
            ) {
                ColumnFlow(spacing: 8) {
                    ForEach(group.readings) { reading in
                        Card {
                            Text(reading.label)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(Self.value(of: reading))
                                .font(.subheadline.monospacedDigit())
                        }
                    }
                }
            }
        } else {
            Screen(title: String(localized: "Live Data"), systemImage: "waveform") {
                ColumnFlow {
                    ExposureScoreCard(score: score, permissions: permissions)
                    ForEach(groups) { group in
                        Card(title: group.name) {
                            ForEach(group.readings.prefix(4)) { reading in
                                HStack(alignment: .firstTextBaseline) {
                                    Text(reading.label)
                                        .foregroundStyle(.secondary)
                                        .layoutPriority(1)
                                    Spacer()
                                    Text(Self.value(of: reading))
                                        .monospacedDigit()
                                        .multilineTextAlignment(.trailing)
                                }
                                .font(.caption)
                            }
                            if group.readings.count > 4 {
                                Text(String(localized: "\(group.readings.count) readings"))
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                }
            }
        }
    }

    private static func value(of reading: SensorReading) -> String {
        [reading.value, reading.unit].compactMap { $0 }.joined(separator: " ")
    }
}

// MARK: - Permissions

private struct PermissionsScreen: View {
    let permissions: [PermissionItem]

    var body: some View {
        Screen(title: String(localized: "Permissions"), systemImage: "lock.shield") {
            ColumnFlow {
                ForEach(PermissionCategory.allCases, id: \.self) { category in
                    let items = permissions.filter { $0.category == category }
                    if !items.isEmpty {
                        Card(title: category.displayName) {
                            ForEach(items) { item in
                                HStack(alignment: .firstTextBaseline, spacing: 8) {
                                    Image(systemName: item.sfSymbol)
                                        .foregroundStyle(item.status.color)
                                        .frame(width: 22)
                                    Text(item.name)
                                    Spacer()
                                    Text(item.status.displayName)
                                        .font(.caption)
                                        .foregroundStyle(item.status.color)
                                        .fixedSize()
                                }
                                .font(.subheadline)
                            }
                        }
                    }
                }
            }
        }
    }
}

private struct PermissionDetailScreen: View {
    let item: PermissionItem
    /// The level whose info sheet is open on the phone, if any.
    let openLevel: GrantLevel?

    var body: some View {
        Screen(title: item.name, systemImage: item.sfSymbol, detail: item.category.displayName) {
            ColumnFlow {
                Card {
                    Text(item.status.displayName)
                        .font(.title3.bold())
                        .foregroundStyle(item.status.color)
                    Text(item.sensitivityTier.displayName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if let note = item.systemNote {
                        Text(note).font(.footnote)
                    }
                }
                if let openLevel {
                    Card(title: openLevel.label) {
                        Text(openLevel.description)
                            .font(.subheadline)
                        Text(String(localized: "What a Developer Can See"))
                            .font(.caption.bold())
                        Text(openLevel.dataAccessSummary)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                Card(title: String(localized: "What Apps Can Do")) {
                    Bullets(items: item.appCapabilities, systemImage: "app.badge.fill")
                }
                Card(title: String(localized: "What Advertisers Can Infer")) {
                    Bullets(items: item.advertiserInferences, systemImage: "chart.bar.fill")
                        .foregroundStyle(.orange)
                }
                Card(title: String(localized: "What You Can't Block")) {
                    ForEach(item.ungatedData, id: \.self) { datum in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(datum.label)
                                .font(.subheadline)
                            if let value = datum.liveValue {
                                Text(value)
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                Card(title: String(localized: "Permission Levels")) {
                    ForEach(item.grantLevels) { level in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(level.label)
                                .font(.subheadline.bold())
                            Text(level.description)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }
}

private struct ContactsScreen: View {
    let contacts: [ContactRecord]
    let query: String

    var body: some View {
        Screen(
            title: String(localized: "Contacts"),
            systemImage: "person.2.fill",
            detail: query.isEmpty
                ? String(localized: "\(contacts.count) readable by this app")
                : String(localized: "\(contacts.count) matching “\(query)”")
        ) {
            FittedGrid(items: contacts, minCellWidth: 210, cellHeight: 80) { contact in
                Card {
                    Text(contact.displayName)
                        .font(.subheadline.bold())
                        .lineLimit(1)
                    Text(String(localized: "\(contact.phoneNumbers.count) phone · \(contact.emailAddresses.count) email · \(contact.postalAddresses.count) address"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

private struct PhotosScreen: View {
    let assets: [PhotoAsset]

    var body: some View {
        Screen(
            title: String(localized: "Your Photos (\(assets.count))"),
            systemImage: "photo.on.rectangle"
        ) {
            FittedGrid(items: assets, minCellWidth: 84, spacing: 4) { asset in
                PhotoThumbnailView(asset: asset)
                    .clipped()
            }
        }
    }
}

// MARK: - Inferred

private struct InferredScreen: View {
    let inferences: [Inference]
    let meaningfulCount: Int

    var body: some View {
        Screen(
            title: String(localized: "Inferred"),
            systemImage: "brain.head.profile",
            detail: String(localized: "\(meaningfulCount) facts with medium or higher confidence")
        ) {
            ColumnFlow(spacing: 8) {
                ForEach(inferences) { inference in
                    Card {
                        HStack(spacing: 6) {
                            Image(systemName: inference.type.sfSymbol)
                                .foregroundStyle(Color.accentColor)
                            Text(inference.label)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            ConfidenceBadgeView(confidence: inference.confidence)
                        }
                        Text(
                            inference.value == .unknown
                                ? String(localized: "Gathering data...")
                                : inference.value.displayString
                        )
                        .font(.subheadline.bold())
                    }
                }
            }
        }
    }
}

private struct InferenceDetailScreen: View {
    let inference: Inference

    var body: some View {
        Screen(
            title: inference.label,
            systemImage: inference.type.sfSymbol,
            detail: inference.category.displayName
        ) {
            ColumnFlow {
                Card {
                    Text(inference.value.displayString)
                        .font(.title3.bold())
                    ConfidenceBadgeView(confidence: inference.confidence)
                    Text(inference.confidenceReason)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Card(title: String(localized: "How We Figured This Out")) {
                    Text(inference.methodology).font(.subheadline)
                }
                if !inference.evidence.isEmpty {
                    Card(title: String(localized: "Evidence")) {
                        EvidenceListView(evidence: inference.evidence)
                    }
                }
                Card(title: String(localized: "Why This Matters")) {
                    Text(inference.databrokerNote).font(.subheadline)
                }
                Card(title: String(localized: "Permissions Driving This")) {
                    Bullets(items: inference.permissionsRequired.map(\.rawValue), systemImage: "lock.fill")
                }
            }
        }
    }
}

// MARK: - History

private struct HistoryScreen: View {
    let snapshots: [ScoreSnapshot]

    var body: some View {
        Screen(title: String(localized: "History"), systemImage: "chart.line.uptrend.xyaxis") {
            if snapshots.isEmpty {
                Text(String(localized: "No history yet. Snapshots of this overview are saved as you use the app."))
                    .foregroundStyle(.secondary)
            } else {
                HStack(alignment: .top, spacing: 12) {
                    Card(title: String(localized: "Permission weight over time")) {
                        ScoreHistoryChart(snapshots: snapshots)
                            .frame(maxHeight: .infinity)
                    }
                    Card(title: String(localized: "Recent Snapshots")) {
                        ForEach(snapshots.suffix(10).reversed()) { snapshot in
                            HStack {
                                Text(snapshot.date, format: .dateTime.month().day().hour().minute())
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("\(snapshot.total)")
                                    .bold()
                                    .monospacedDigit()
                                    .foregroundStyle(Color.accentColor)
                            }
                            .font(.subheadline)
                        }
                    }
                    .frame(width: 260)
                }
            }
        }
    }
}

// MARK: - About

private struct AboutScreen: View {
    let version: String

    var body: some View {
        Screen(
            title: String(localized: "About"),
            systemImage: "info.circle",
            detail: String(localized: "Version \(version)")
        ) {
            ColumnFlow {
                Card {
                    Text(AboutView.summary).font(.subheadline)
                }
                Card(title: String(localized: "Our Principles")) {
                    ForEach(AboutView.principles, id: \.0) { symbol, text in
                        Label(text, systemImage: symbol).font(.subheadline)
                    }
                }
                Card(title: String(localized: "What We Cannot Do")) {
                    Bullets(items: AboutView.cannotDo, systemImage: "xmark.circle")
                }
                Card(title: String(localized: "Sensor Data That Can't Be Blocked")) {
                    Bullets(items: AboutView.alwaysReadable, systemImage: "circle.fill")
                }
            }
        }
    }
}

#Preview("16:9", traits: .fixedLayout(width: 960, height: 540)) {
    ExternalDisplayView(
        store: Store(initialState: AppFeature.State(selectedSection: .permissions, hasSeenPrimer: true)) {
            AppFeature()
        } withDependencies: {
            $0.sensorClient = .testValue
            $0.permissionClient = .testValue
        }
    )
}
