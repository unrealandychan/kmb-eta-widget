import WidgetKit
import SwiftUI
import AppIntents

// MARK: - SavedStop AppEntity (for Widget picker dropdown)

struct SavedStopEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "巴士站"
    static var defaultQuery = SavedStopQuery()

    var id: String          // stopID
    var displayName: String // label / nameTc

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(displayName)", subtitle: "\(id)")
    }
}

struct SavedStopQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [SavedStopEntity] {
        let config = WidgetConfig.load()
        return config.stops
            .filter { identifiers.contains($0.stopID) }
            .map { SavedStopEntity(id: $0.stopID, displayName: $0.label) }
    }

    func suggestedEntities() async throws -> [SavedStopEntity] {
        let config = WidgetConfig.load()
        return config.stops.map { SavedStopEntity(id: $0.stopID, displayName: $0.label) }
    }

    func defaultResult() async -> SavedStopEntity? {
        let config = WidgetConfig.load()
        guard let first = config.stops.first else { return nil }
        return SavedStopEntity(id: first.stopID, displayName: first.label)
    }
}

// MARK: - Widget Configuration Intent (lets user pick a stop per widget)

struct SelectStopIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "選擇巴士站"
    static var description = IntentDescription("選擇要顯示的九巴站")

    @Parameter(title: "巴士站")
    var stop: SavedStopEntity?
}

// MARK: - Timeline Entry

struct KMBEntry: TimelineEntry {
    let date: Date
    let stop: SavedStop?
    let routes: [RouteEta]
    let error: String?

    static let placeholder = KMBEntry(
        date: Date(),
        stop: SavedStop(stopID: "SAMPLE", label: "樓下巴士站", nameTc: "樓下巴士站"),
        routes: [
            RouteEta(route: "234",  dest: "旺角（荔枝角道）", etas: [3, 15, 22]),
            RouteEta(route: "98C",  dest: "荔枝角",           etas: [7, 19]),
            RouteEta(route: "N234", dest: "深水埗",           etas: [0]),
        ],
        error: nil
    )
}

// MARK: - Timeline Provider

struct KMBProvider: AppIntentTimelineProvider {
    typealias Entry = KMBEntry
    typealias Intent = SelectStopIntent

    func placeholder(in context: Context) -> KMBEntry {
        .placeholder
    }

    func snapshot(for configuration: SelectStopIntent, in context: Context) async -> KMBEntry {
        await fetchEntry(configuration: configuration)
    }

    func timeline(for configuration: SelectStopIntent, in context: Context) async -> Timeline<KMBEntry> {
        let entry = await fetchEntry(configuration: configuration)
        // Refresh every 5 minutes
        let next = Calendar.current.date(byAdding: .minute, value: 5, to: Date())!
        return Timeline(entries: [entry], policy: .after(next))
    }

    private func fetchEntry(configuration: SelectStopIntent) async -> KMBEntry {
        // Resolve which stop to show — from AppEntity picker or fallback to first saved
        let config = WidgetConfig.load()
        // DEBUG: log path so we can verify
        let url = WidgetConfig.configFileURL
        let exists = FileManager.default.fileExists(atPath: url.path)
        NSLog("[KMBWidget] configFileURL=\(url.path) exists=\(exists) stops=\(config.stops.count)")
        let stop: SavedStop?
        if let entity = configuration.stop {
            stop = config.stops.first(where: { $0.stopID == entity.id })
               ?? SavedStop(stopID: entity.id, label: entity.displayName, nameTc: entity.displayName)
        } else {
            stop = config.stops.first
        }

        guard let stop else {
            return KMBEntry(date: Date(), stop: nil, routes: [], error: "未設定巴士站\n請先開啟 App 新增")
        }

        do {
            let routes = try await KMBAPIClient.routeEtas(for: stop.stopID)
            return KMBEntry(date: Date(), stop: stop, routes: routes, error: nil)
        } catch {
            return KMBEntry(date: Date(), stop: stop, routes: [], error: "無法載入數據")
        }
    }
}

// MARK: - Widget Views

struct KMBWidgetSmallView: View {
    let entry: KMBEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Image(systemName: "bus.fill")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
                Text(entry.stop?.label ?? "巴士站")
                    .font(.caption2.bold())
                    .foregroundStyle(.white.opacity(0.8))
                    .lineLimit(1)
                Spacer()
            }
            .padding(.bottom, 6)

            if let error = entry.error {
                Spacer()
                Text(error)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                Spacer()
            } else if entry.routes.isEmpty {
                Spacer()
                Text("暫無班次")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
                Spacer()
            } else {
                ForEach(entry.routes.prefix(3)) { r in
                    smallRouteRow(r)
                }
                Spacer()
            }

            // Footer timestamp
            Text(entry.date.formatted(date: .omitted, time: .shortened))
                .font(.system(size: 9))
                .foregroundStyle(.white.opacity(0.4))
        }
        .padding(12)
        .containerBackground(
            LinearGradient(colors: [Color(hex: "#1C2C4C"), Color(hex: "#2A3E6E")],
                           startPoint: .topLeading, endPoint: .bottomTrailing),
            for: .widget
        )
    }

    func smallRouteRow(_ r: RouteEta) -> some View {
        HStack(spacing: 4) {
            Text(r.route)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
                .frame(width: 38, alignment: .leading)
            Spacer()
            Text(r.etaText)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(urgencyColor(r.nextMins))
        }
        .padding(.vertical, 2)
    }
}

struct KMBWidgetMediumView: View {
    let entry: KMBEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Header
            HStack {
                Label(entry.stop?.label ?? "巴士站", systemImage: "bus.fill")
                    .font(.caption.bold())
                    .foregroundStyle(.white.opacity(0.8))
                Spacer()
                Text(entry.date.formatted(date: .omitted, time: .shortened))
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.4))
            }
            .padding(.bottom, 2)

            Divider().overlay(.white.opacity(0.15))

            if let error = entry.error {
                Text(error)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.6))
            } else {
                ForEach(entry.routes.prefix(4)) { r in
                    mediumRouteRow(r)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .containerBackground(
            LinearGradient(colors: [Color(hex: "#1C2C4C"), Color(hex: "#2A3E6E")],
                           startPoint: .topLeading, endPoint: .bottomTrailing),
            for: .widget
        )
    }

    func mediumRouteRow(_ r: RouteEta) -> some View {
        HStack(spacing: 8) {
            Text(r.route)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
                .frame(width: 44, alignment: .leading)

            Text(r.dest)
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.65))
                .lineLimit(1)

            Spacer()

            HStack(spacing: 6) {
                ForEach(Array(r.etas.prefix(3).enumerated()), id: \.offset) { idx, m in
                    etaBadge(m, primary: idx == 0)
                }
            }
        }
    }

    @ViewBuilder
    func etaBadge(_ mins: Int?, primary: Bool) -> some View {
        let text: String = {
            guard let m = mins else { return "—" }
            if m <= 0 { return "即將" }
            return "\(m)分"
        }()
        let color = urgencyColor(mins)

        Text(text)
            .font(.system(size: primary ? 13 : 11, weight: primary ? .bold : .regular, design: .monospaced))
            .foregroundStyle(primary ? color : .white.opacity(0.45))
            .padding(.horizontal, primary ? 6 : 4)
            .padding(.vertical, 2)
            .background(primary ? color.opacity(0.18) : .clear)
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

struct KMBWidgetLargeView: View {
    let entry: KMBEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(entry.stop?.label ?? "巴士站", systemImage: "bus.fill")
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                Spacer()
                Text(entry.date.formatted(date: .omitted, time: .standard))
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.4))
            }

            Divider().overlay(.white.opacity(0.15))

            if let error = entry.error {
                Spacer()
                Text(error).font(.callout).foregroundStyle(.white.opacity(0.6))
                Spacer()
            } else {
                ForEach(entry.routes.prefix(8)) { r in
                    largeRouteRow(r)
                }
                Spacer(minLength: 0)
            }
        }
        .padding(16)
        .containerBackground(
            LinearGradient(colors: [Color(hex: "#1C2C4C"), Color(hex: "#162340")],
                           startPoint: .top, endPoint: .bottom),
            for: .widget
        )
    }

    func largeRouteRow(_ r: RouteEta) -> some View {
        HStack(spacing: 10) {
            Text(r.route)
                .font(.system(size: 15, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
                .frame(width: 50, alignment: .leading)

            Text(r.dest)
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.65))
                .lineLimit(1)

            Spacer()

            HStack(spacing: 8) {
                ForEach(Array(r.etas.prefix(3).enumerated()), id: \.offset) { idx, m in
                    let text: String = {
                        guard let m else { return "—" }
                        if m <= 0 { return "即將" }
                        return "\(m) 分"
                    }()
                    Text(text)
                        .font(.system(size: idx == 0 ? 14 : 12,
                                      weight: idx == 0 ? .bold : .regular,
                                      design: .monospaced))
                        .foregroundStyle(idx == 0 ? urgencyColor(m) : .white.opacity(0.45))
                        .frame(minWidth: idx == 0 ? 44 : 32, alignment: .trailing)
                }
            }
        }
        .padding(.vertical, 3)
    }
}

// MARK: - Urgency Color Helper (shared)

func urgencyColor(_ mins: Int?) -> Color {
    guard let m = mins else { return .white.opacity(0.4) }
    if m <= 0 { return Color(hex: "#FF453A") }
    if m <= 2 { return Color(hex: "#FF453A") }
    if m <= 5 { return Color(hex: "#FF9F0A") }
    return Color(hex: "#32D74B")
}

// MARK: - Widget Entry Point

struct KMBWidgetExtension: Widget {
    let kind = "KMBWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: SelectStopIntent.self,
            provider: KMBProvider()
        ) { entry in
            KMBWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("九巴到站時間")
        .description("顯示樓下巴士站嘅實時到站時間")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct KMBWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: KMBEntry

    var body: some View {
        switch family {
        case .systemSmall:  KMBWidgetSmallView(entry: entry)
        case .systemMedium: KMBWidgetMediumView(entry: entry)
        default:            KMBWidgetLargeView(entry: entry)
        }
    }
}

// MARK: - Widget Bundle

@main
struct KMBWidgetBundle: WidgetBundle {
    var body: some Widget {
        KMBWidgetExtension()
    }
}

// MARK: - Color Hex Extension

extension Color {
    init(hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: h).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8)  & 0xFF) / 255
        let b = Double(int         & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
