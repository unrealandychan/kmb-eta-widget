import Foundation
import Combine

// MARK: - Background ETA Poller (macOS — replaces iOS BGAppRefreshTask)
// Uses a Combine Timer, polls every 30 seconds while app is running.

final class BackgroundPoller {
    static let shared = BackgroundPoller()
    private var timer: AnyCancellable?

    func start() {
        guard timer == nil else { return }
        Task { await NotificationManager.shared.checkAndFireReminders() }
        timer = Timer.publish(every: 30, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                Task { await NotificationManager.shared.checkAndFireReminders() }
            }
    }

    func stop() { timer = nil }
}
