import Foundation
import UserNotifications

// MARK: - Reminder Model

struct BusReminder: Codable, Identifiable, Hashable {
    var id: String = UUID().uuidString
    let stopID: String
    let stopLabel: String
    let route: String
    let dest: String
    let minutesBefore: Int
    var isEnabled: Bool = true
}

// MARK: - Notification Manager

@MainActor
final class NotificationManager: ObservableObject {
    static let shared = NotificationManager()

    @Published var authStatus: UNAuthorizationStatus = .notDetermined
    @Published var reminders: [BusReminder] = []

    private let center = UNUserNotificationCenter.current()
    private let remindersKey = "busReminders"
    private var remindersFileURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("KMBWidget", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("reminders.json")
    }

    init() {
        loadReminders()
        Task { await refreshAuthStatus() }
    }

    // MARK: - Permission

    func requestPermission() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            await refreshAuthStatus()
            return granted
        } catch { return false }
    }

    func refreshAuthStatus() async {
        let settings = await center.notificationSettings()
        authStatus = settings.authorizationStatus
    }

    // MARK: - CRUD

    func addReminder(_ r: BusReminder) {
        reminders.append(r)
        saveReminders()
    }

    func deleteReminder(id: String) {
        reminders.removeAll { $0.id == id }
        saveReminders()
    }

    func toggleReminder(id: String) {
        if let idx = reminders.firstIndex(where: { $0.id == id }) {
            reminders[idx].isEnabled.toggle()
            saveReminders()
        }
    }

    // MARK: - Check & Fire (called by BackgroundPoller every 30s)

    func checkAndFireReminders() async {
        guard !reminders.isEmpty else { return }
        // Group reminders by stopID to minimise API calls
        let grouped = Dictionary(grouping: reminders.filter(\.isEnabled), by: \.stopID)
        for (stopID, stopReminders) in grouped {
            guard let etas = try? await KMBAPIClient.routeEtas(for: stopID) else { continue }
            for reminder in stopReminders {
                fireIfNeeded(reminder: reminder, etas: etas)
            }
        }
    }

    func fireIfNeeded(reminder: BusReminder, etas: [RouteEta]) {
        guard reminder.isEnabled else { return }
        guard let match = etas.first(where: { $0.route == reminder.route && $0.dest == reminder.dest }),
              let mins = match.nextMins, mins <= reminder.minutesBefore, mins >= 0
        else { return }

        let content = UNMutableNotificationContent()
        content.title = "🚌 \(reminder.route) 快到喇！"
        content.body = mins == 0
            ? "\(reminder.route) 往 \(reminder.dest) 即將到達 \(reminder.stopLabel)"
            : "\(reminder.route) 往 \(reminder.dest) 約 \(mins) 分鐘後到達 \(reminder.stopLabel)"
        content.sound = .default

        let req = UNNotificationRequest(
            identifier: "eta-\(reminder.id)-\(mins)",
            content: content,
            trigger: nil
        )
        center.add(req)
    }

    // MARK: - Persistence

    private func saveReminders() {
        if let data = try? JSONEncoder().encode(reminders) {
            try? data.write(to: remindersFileURL, options: .atomic)
        }
    }

    private func loadReminders() {
        guard
            let data = try? Data(contentsOf: remindersFileURL),
            let loaded = try? JSONDecoder().decode([BusReminder].self, from: data)
        else { return }
        reminders = loaded
    }
}
