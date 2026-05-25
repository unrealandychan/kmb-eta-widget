import Foundation

// MARK: - Shared Models (used by both App & Widget)

struct KMBStop: Codable, Identifiable, Hashable {
    var id: String { stopID }
    let stopID: String
    let nameTc: String
    let nameEn: String
    let lat: String
    let long: String

    enum CodingKeys: String, CodingKey {
        case stopID = "stop"
        case nameTc = "name_tc"
        case nameEn = "name_en"
        case lat, long
    }
}

struct KMBEtaEntry: Codable, Identifiable {
    var id: String { "\(route)-\(seq)-\(eta ?? "nil")" }
    let route: String
    let dir: String
    let serviceType: Int
    let seq: Int
    let destTc: String?
    let destEn: String?
    let eta: String?          // ISO-8601 timestamp
    let etaSeq: Int
    let rmkTc: String?

    enum CodingKeys: String, CodingKey {
        case route, dir, seq, eta
        case serviceType = "service_type"
        case destTc = "dest_tc"
        case destEn = "dest_en"
        case etaSeq  = "eta_seq"
        case rmkTc   = "rmk_tc"
    }

    var minutesUntil: Int? {
        guard let eta else { return nil }
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime]
        guard let date = fmt.date(from: eta) else { return nil }
        let mins = Int(date.timeIntervalSinceNow / 60)
        return mins
    }

    var destDisplay: String {
        destTc ?? destEn ?? "—"
    }
}

// Per-route grouping for display
struct RouteEta: Identifiable {
    var id: String { route + dest }
    let route: String
    let dest: String
    let etas: [Int?]   // up to 3 upcoming, nil = no data

    var nextMins: Int? { etas.compactMap { $0 }.first }

    var urgencyColor: String {
        guard let m = nextMins else { return "etaGray" }
        if m <= 2  { return "etaRed"    }
        if m <= 5  { return "etaOrange" }
        return "etaGreen"
    }

    var etaText: String {
        guard let m = nextMins else { return "—" }
        if m <= 0 { return "即將到達" }
        return "\(m) 分鐘"
    }
}

// Saved configuration (stored in App Group UserDefaults)
struct SavedStop: Codable, Identifiable, Hashable {
    var id: String { stopID }
    let stopID: String
    let label: String      // user custom name
    let nameTc: String
}

struct WidgetConfig: Codable {
    var stops: [SavedStop]
    static let `default` = WidgetConfig(stops: [])
}

// MARK: - Shared Constants

let kAppGroup = "group.com.eddie.kmbwidget"

// MARK: - WidgetConfig Persistence (App Group UserDefaults)

extension WidgetConfig {
    // File-based storage — shared path accessible by both App and Widget Extension
    static var configFileURL: URL {
        #if WIDGET_EXTENSION
        // Extension runs outside sandbox, read directly from main app container
        let home = FileManager.default.homeDirectoryForCurrentUser
        let dir = home.appendingPathComponent(
            "Library/Containers/com.eddie.kmbwidget/Data/Library/Application Support/KMBWidget",
            isDirectory: true)
        #else
        // Main app: use standard Application Support (sandboxed path resolves correctly)
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("KMBWidget", isDirectory: true)
        #endif
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("widgetConfig.json")
    }

    static func load() -> WidgetConfig {
        guard
            let data = try? Data(contentsOf: configFileURL),
            let config = try? JSONDecoder().decode(WidgetConfig.self, from: data)
        else { return .default }
        return config
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        try? data.write(to: WidgetConfig.configFileURL, options: .atomic)
    }
}
