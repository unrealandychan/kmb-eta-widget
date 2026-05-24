import SwiftUI

// MARK: - Stop Detail + Reminders (combined view)

struct StopDetailWithRemindersView: View {
    let stop: SavedStop
    @StateObject private var nm = NotificationManager.shared
    @State private var routes: [RouteEta] = []
    @State private var isLoading = true
    @State private var showAddReminder = false
    @Environment(\.dismiss) var dismiss

    var stopReminders: [BusReminder] {
        nm.reminders.filter { $0.stopID == stop.stopID }
    }

    var body: some View {
        List {
            // ETA section
            Section("實時到站") {
                if isLoading {
                    HStack { ProgressView(); Text("載入中…").foregroundStyle(.secondary) }
                } else if routes.isEmpty {
                    Text("暫無班次").foregroundStyle(.secondary)
                } else {
                    ForEach(routes) { r in
                        ETARow(route: r)
                    }
                }
            }

            // Reminders section
            Section {
                if stopReminders.isEmpty {
                    Text("未設定任何提醒").foregroundStyle(.secondary).font(.subheadline)
                } else {
                    ForEach(stopReminders) { reminder in
                        ReminderRow(reminder: reminder)
                    }
                    .onDelete { idx in
                        let toDelete = idx.map { stopReminders[$0].id }
                        toDelete.forEach { nm.deleteReminder(id: $0) }
                    }
                }
            } header: {
                HStack {
                    Text("提醒")
                    Spacer()
                    Button { showAddReminder = true } label: {
                        Label("新增", systemImage: "plus")
                            .font(.caption.bold())
                    }
                }
            }

            // Notification permission banner
            if nm.authStatus == .denied {
                Section {
                    Label("請在設定中開啟通知權限", systemImage: "bell.slash.fill")
                        .foregroundStyle(.orange)
                    Button("開啟設定") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") {
                    NSWorkspace.shared.open(url)
                }
                    }
                }
            }
        }
        .navigationTitle(stop.label)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("關閉") { dismiss() }
            }
        }
        .task { await loadData() }
        .refreshable { await loadData() }
        .sheet(isPresented: $showAddReminder) {
            AddReminderSheet(stop: stop, routes: routes)
        }
        .onAppear {
            Task { await nm.refreshAuthStatus() }
            if nm.authStatus == .notDetermined {
                Task { await nm.requestPermission() }
            }
        }
    }

    func loadData() async {
        isLoading = routes.isEmpty
        routes = (try? await KMBAPIClient.routeEtas(for: stop.stopID)) ?? []
        isLoading = false
    }
}

// MARK: - Reminder Row

struct ReminderRow: View {
    @StateObject private var nm = NotificationManager.shared
    let reminder: BusReminder

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "bell.fill")
                .foregroundStyle(reminder.isEnabled ? .orange : .secondary)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(reminder.route)
                        .font(.headline)
                    Text("→ \(reminder.dest)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Text("到站前 \(reminder.minutesBefore) 分鐘提醒")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("", isOn: Binding(
                get: { reminder.isEnabled },
                set: { _ in nm.toggleReminder(id: reminder.id) }
            ))
            .labelsHidden()
        }
    }
}

// MARK: - Add Reminder Sheet

struct AddReminderSheet: View {
    let stop: SavedStop
    let routes: [RouteEta]
    @StateObject private var nm = NotificationManager.shared
    @Environment(\.dismiss) var dismiss

    @State private var selectedRoute: RouteEta?
    @State private var minutesBefore = 5

    var body: some View {
        NavigationStack {
            Form {
                Section("選擇路線") {
                    if routes.isEmpty {
                        Text("暫無班次資料").foregroundStyle(.secondary)
                    } else {
                        ForEach(routes) { r in
                            Button {
                                selectedRoute = r
                            } label: {
                                HStack {
                                    Text(r.route).font(.headline.monospaced())
                                    Text(r.dest).foregroundStyle(.secondary).lineLimit(1)
                                    Spacer()
                                    if selectedRoute?.id == r.id {
                                        Image(systemName: "checkmark").foregroundStyle(.blue)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Section("提前幾分鐘提醒？") {
                    Picker("分鐘", selection: $minutesBefore) {
                        Text("1 分鐘").tag(1)
                        Text("3 分鐘").tag(3)
                        Text("5 分鐘").tag(5)
                        Text("10 分鐘").tag(10)
                        Text("15 分鐘").tag(15)
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 120)
                }

                if let r = selectedRoute {
                    Section("確認") {
                        Label("當 \(r.route) 往 \(r.dest) 距離 \(stop.label) 少於 \(minutesBefore) 分鐘時通知你",
                              systemImage: "bell.badge.fill")
                            .font(.subheadline)
                            .foregroundStyle(.orange)
                    }
                }
            }
            .navigationTitle("新增提醒")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("新增") {
                        guard let r = selectedRoute else { return }
                        let reminder = BusReminder(
                            stopID: stop.stopID,
                            stopLabel: stop.label,
                            route: r.route,
                            dest: r.dest,
                            minutesBefore: minutesBefore
                        )
                        nm.addReminder(reminder)
                        dismiss()
                    }
                    .bold()
                    .disabled(selectedRoute == nil)
                }
            }
        }
    }
}
