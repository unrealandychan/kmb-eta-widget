import BackgroundTasks
import UIKit

// MARK: - Background ETA Checker
// BGAppRefreshTask: iOS wakes the app periodically (~15 min minimum)
// We check all enabled reminders and fire notifications if ETA threshold met.

let kBGTaskID = "com.eddie.kmbwidget.etacheck"

struct BackgroundTaskManager {

    // Call once in App.init / AppDelegate
    static func register() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: kBGTaskID, using: nil) { task in
            guard let refreshTask = task as? BGAppRefreshTask else { return }
            handle(refreshTask)
        }
    }

    // Call when app goes to background (scenePhase == .background)
    static func schedule() {
        let request = BGAppRefreshTaskRequest(identifier: kBGTaskID)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 5 * 60)  // earliest 5 min later
        try? BGTaskScheduler.shared.submit(request)
    }

    // MARK: - Handler
    private static func handle(_ task: BGAppRefreshTask) {
        // Schedule next run immediately
        schedule()

        let checkTask = Task {
            await checkAllReminders()
            task.setTaskCompleted(success: true)
        }
        task.expirationHandler = { checkTask.cancel() }
    }

    // MARK: - Core check logic (also callable from foreground)
    @discardableResult
    static func checkAllReminders() async -> Int {
        let reminders = NotificationManager.shared.reminders.filter { $0.isEnabled }
        guard !reminders.isEmpty else { return 0 }

        // Group reminders by stopID to minimise API calls
        let grouped = Dictionary(grouping: reminders, by: \.stopID)
        var fired = 0

        await withTaskGroup(of: Void.self) { group in
            for (stopID, stopReminders) in grouped {
                group.addTask {
                    guard let etas = try? await KMBAPIClient.routeEtas(for: stopID) else { return }
                    await MainActor.run {
                        for reminder in stopReminders {
                            NotificationManager.shared.fireIfNeeded(reminder: reminder, etas: etas)
                            fired += 1
                        }
                    }
                }
            }
        }
        return fired
    }
}
