import SwiftUI
import BackgroundTasks

@main
struct KMBWidgetApp: App {

    init() {
        BackgroundTaskManager.register()
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .onChange(of: scenePhase) { _, phase in
                    if phase == .background {
                        BackgroundTaskManager.schedule()
                    }
                }
        }
    }

    @Environment(\.scenePhase) private var scenePhase
}

// MARK: - Main Tab View
struct MainTabView: View {
    var body: some View {
        TabView {
            NavigationStack { ContentView() }
                .tabItem { Label("我的巴士站", systemImage: "star.fill") }

            NavigationStack { NearbyStopsView() }
                .tabItem { Label("附近巴士站", systemImage: "location.fill") }

            NavigationStack { RemindersListView() }
                .tabItem { Label("提醒", systemImage: "bell.fill") }
        }
    }
}

// MARK: - All Reminders Overview
struct RemindersListView: View {
    @StateObject private var nm = NotificationManager.shared

    var body: some View {
        List {
            if nm.authStatus == .denied {
                Section {
                    Label("通知權限被關閉，提醒無法發送", systemImage: "bell.slash.fill")
                        .foregroundStyle(.orange)
                    Button("開啟設定") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                }
            }

            if nm.reminders.isEmpty {
                ContentUnavailableView(
                    "未設定提醒",
                    systemImage: "bell.slash",
                    description: Text("去「附近巴士站」或「我的巴士站」搵路線並新增提醒")
                )
            } else {
                ForEach(nm.reminders) { reminder in
                    ReminderRow(reminder: reminder)
                }
                .onDelete { idx in
                    let toDelete = idx.map { nm.reminders[$0].id }
                    toDelete.forEach { nm.deleteReminder(id: $0) }
                }
            }
        }
        .navigationTitle("🔔 提醒")
        .toolbar {
            if !nm.reminders.isEmpty { EditButton() }
        }
        .onAppear { Task { await nm.refreshAuthStatus() } }
    }
}
