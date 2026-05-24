import SwiftUI

@main
struct KMBWidgetApp: App {
    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
    }
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
    @State private var editMode = false

    var body: some View {
        List {
            if nm.authStatus == .denied {
                Section {
                    Label("通知權限被關閉，提醒無法發送", systemImage: "bell.slash.fill")
                        .foregroundStyle(.orange)
                    Button("開啟系統設定") {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") {
                            NSWorkspace.shared.open(url)
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
                    HStack {
                        ReminderRow(reminder: reminder)
                        if editMode {
                            Spacer()
                            Button(role: .destructive) {
                                nm.deleteReminder(id: reminder.id)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .navigationTitle("🔔 提醒")
        .toolbar {
            if !nm.reminders.isEmpty {
                Button(editMode ? "完成" : "編輯") {
                    editMode.toggle()
                }
            }
        }
        .onAppear { Task { await nm.refreshAuthStatus() } }
    }
}
