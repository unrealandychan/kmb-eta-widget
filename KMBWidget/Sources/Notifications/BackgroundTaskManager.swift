import Foundation
import Combine
import SwiftUI

// MARK: - macOS: 用 Timer 代替 BGAppRefreshTask
// 每 30 秒 poll 一次 ETA，睇下有無符合提醒條件

final class BackgroundPoller: ObservableObject {
    static let shared = BackgroundPoller()
    private var timer: AnyCancellable?

    func start() {
        guard timer == nil else { return }
        // 立即跑一次，之後每 30 秒
        Task { await NotificationManager.shared.checkAllReminders() }
        timer = Timer.publish(every: 30, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                Task { await NotificationManager.shared.checkAllReminders() }
            }
    }

    func stop() { timer = nil }
}
