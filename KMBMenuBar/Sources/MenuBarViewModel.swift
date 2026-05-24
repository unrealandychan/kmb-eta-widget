import Foundation
import Combine
import SwiftUI

// MARK: - Menu Bar View Model
// Polls ETA every 30 seconds, drives the label countdown + popover list.

@MainActor
final class MenuBarViewModel: ObservableObject {

    // Persisted config (shared with iOS via iCloud or standalone on Mac)
    @Published var stops: [SavedStop] = []
    @Published var etaByStop: [String: [RouteEta]] = [:]   // stopID → routes
    @Published var lastUpdated: Date?
    @Published var isRefreshing = false
    @Published var errorMessage: String?

    // Convenience: flat top routes across all stops for the menu bar label
    var topRoutes: [RouteEta] {
        stops.flatMap { etaByStop[$0.stopID] ?? [] }
            .sorted { ($0.nextMins ?? 999) < ($1.nextMins ?? 999) }
    }

    private var timer: AnyCancellable?
    private let defaults = UserDefaults(suiteName: kAppGroup) ?? .standard

    init() {
        loadConfig()
        startPolling()
    }

    // MARK: - Polling

    func startPolling() {
        // Fire immediately, then every 30 seconds
        Task { await refresh() }
        timer = Timer.publish(every: 30, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task { await self?.refresh() }
            }
    }

    func stopPolling() { timer = nil }

    func refresh() async {
        guard !stops.isEmpty else { return }
        isRefreshing = true
        errorMessage = nil

        await withTaskGroup(of: (String, [RouteEta]).self) { group in
            for stop in stops {
                group.addTask {
                    let routes = (try? await KMBAPIClient.routeEtas(for: stop.stopID)) ?? []
                    return (stop.stopID, routes)
                }
            }
            for await (sid, routes) in group {
                etaByStop[sid] = routes
            }
        }

        lastUpdated = Date()
        isRefreshing = false
    }

    // MARK: - Stop Management

    func addStop(_ stop: SavedStop) {
        guard !stops.contains(where: { $0.stopID == stop.stopID }) else { return }
        stops.append(stop)
        saveConfig()
        Task { await refresh() }
    }

    func removeStop(id: String) {
        stops.removeAll { $0.stopID == id }
        etaByStop.removeValue(forKey: id)
        saveConfig()
    }

    func moveStop(from: IndexSet, to: Int) {
        stops.move(fromOffsets: from, toOffset: to)
        saveConfig()
    }

    // MARK: - Persistence (Mac-local UserDefaults, or App Group if also building iOS)

    private func saveConfig() {
        if let data = try? JSONEncoder().encode(stops) {
            defaults.set(data, forKey: "macMenuBarStops")
        }
    }

    private func loadConfig() {
        guard
            let data = defaults.data(forKey: "macMenuBarStops"),
            let saved = try? JSONDecoder().decode([SavedStop].self, from: data)
        else { return }
        stops = saved
    }
}

// MARK: - RouteEta Mac helpers

extension RouteEta {
    var shortEta: String {
        guard let m = nextMins else { return "—" }
        if m <= 0 { return "即到" }
        return "\(m)m"
    }

    var swiftUIUrgencyColor: Color {
        guard let m = nextMins else { return .secondary }
        if m <= 2 { return .red }
        if m <= 5 { return .orange }
        return .green
    }
}
