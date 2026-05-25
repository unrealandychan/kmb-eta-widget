import SwiftUI
import WidgetKit
import AppKit

// MARK: - Main App ContentView

struct ContentView: View {
    @State private var config = WidgetConfig.load()
    @State private var showSearch = false
    @State private var editMode = false

    var body: some View {
        NavigationStack {
            Group {
                if config.stops.isEmpty {
                    emptyState
                } else {
                    stopList
                }
            }
            .navigationTitle("🚌 KMB Widget")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showSearch = true } label: {
                        Label("新增巴士站", systemImage: "plus")
                    }
                }
                if !config.stops.isEmpty {
                    ToolbarItem(placement: .automatic) {
                        Button(editMode ? "完成" : "編輯") {
                            editMode.toggle()
                        }
                    }
                }
            }
            .sheet(isPresented: $showSearch) {
                StopSearchView { stop in
                    let saved = SavedStop(stopID: stop.stopID, label: stop.nameTc, nameTc: stop.nameTc)
                    if !config.stops.contains(where: { $0.stopID == saved.stopID }) {
                        config.stops.append(saved)
                        config.save()
                        WidgetCenter.shared.reloadAllTimelines()
                    }
                }
            }
        }
    }

    var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "bus.fill")
                .font(.system(size: 60))
                .foregroundStyle(.blue)
            Text("未設定巴士站")
                .font(.title2.bold())
            Text("點擊右上角「+」搜尋你樓下嘅巴士站")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("新增巴士站") { showSearch = true }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        }
        .padding()
    }

    var stopList: some View {
        List {
            ForEach(config.stops) { stop in
                HStack {
                    NavigationLink(destination: StopDetailView(stop: stop)) {
                        stopRow(stop)
                    }
                    if editMode {
                        Spacer()
                        Button(role: .destructive) {
                            config.stops.removeAll { $0.stopID == stop.stopID }
                            config.save()
                            WidgetCenter.shared.reloadAllTimelines()
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .onMove { from, to in
                config.stops.move(fromOffsets: from, toOffset: to)
                config.save()
                WidgetCenter.shared.reloadAllTimelines()
            }

            Section {
                Text("Widget 每 5 分鐘自動更新。在桌面長按 Widget 可選擇顯示哪個巴士站。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    func stopRow(_ stop: SavedStop) -> some View {
        HStack {
            Image(systemName: "mappin.circle.fill")
                .foregroundStyle(.blue)
                .font(.title2)
            VStack(alignment: .leading, spacing: 2) {
                Text(stop.label).font(.headline)
                Text(stop.stopID).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Stop Search View

struct StopSearchView: View {
    var onSelect: (KMBStop) -> Void
    @Environment(\.dismiss) var dismiss
    @State private var query = ""
    @State private var results: [KMBStop] = []
    @State private var isLoading = false
    @State private var error: String?
    @State private var selectedStop: KMBStop?
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("搜尋巴士站")
                    .font(.headline)
                Spacer()
                Button("取消") { dismiss() }
                    .keyboardShortcut(.escape, modifiers: [])
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 10)

            Divider()

            // Search bar
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("輸入地區或站名，例如：旺角", text: $query)
                    .textFieldStyle(.plain)
                    .focused($searchFocused)
                    .onSubmit {
                        if query.count >= 1 {
                            Task { await search(query) }
                        }
                    }
                if !query.isEmpty {
                    Button {
                        query = ""
                        results = []
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(10)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(searchFocused ? Color.accentColor : Color.clear, lineWidth: 2))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            // Search button
            HStack {
                Button {
                    Task { await search(query) }
                } label: {
                    Label("搜尋", systemImage: "magnifyingglass")
                }
                .buttonStyle(.borderedProminent)
                .disabled(query.isEmpty)
                Spacer()
                if isLoading {
                    ProgressView().scaleEffect(0.8)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)

            Divider()

            // Results
            if let error {
                VStack {
                    Spacer()
                    Text("❌ \(error)").foregroundStyle(.red)
                    Spacer()
                }
            } else if results.isEmpty && !isLoading {
                VStack {
                    Spacer()
                    if query.count >= 1 {
                        Text("找不到「\(query)」相關巴士站")
                            .foregroundStyle(.secondary)
                    } else {
                        Text("輸入站名搜尋")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
            } else {
                // Use List instead of ScrollView+LazyVStack — macOS List handles
                // click events reliably; ScrollView+LazyVStack intercepts taps as scroll gestures
                List(results) { stop in
                    stopRow(stop)
                }
                .listStyle(.plain)
            }
        }
        .frame(minWidth: 440, minHeight: 500)
        .background(Color(nsColor: .windowBackgroundColor))
        // Fix: use .task for focus — waits for sheet animation to complete
        // before setting focus, unlike onAppear which fires too early
        .task {
            try? await Task.sleep(for: .milliseconds(500))
            await MainActor.run {
                NSApp.activate(ignoringOtherApps: true)
                searchFocused = true
            }
        }
        .onChange(of: query) { _, new in
            guard new.count >= 2 else {
                if new.isEmpty { results = [] }
                return
            }
            Task {
                try? await Task.sleep(for: .milliseconds(400))
                if query == new { await search(new) }
            }
        }
    }

    func stopRow(_ stop: KMBStop) -> some View {
        VStack(spacing: 0) {
            Button {
                onSelect(stop)
                dismiss()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundStyle(.blue)
                        .font(.title3)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(stop.nameTc)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text(stop.nameEn)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("站號：\(stop.stopID)")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .background(selectedStop?.stopID == stop.stopID ? Color.accentColor.opacity(0.1) : Color.clear)
            .onHover { hovering in
                if hovering { selectedStop = stop } else { selectedStop = nil }
            }

            Divider().padding(.leading, 52)
        }
    }

    func search(_ kw: String) async {
        guard !kw.isEmpty else { return }
        isLoading = true
        error = nil
        do {
            results = try await KMBAPIClient.searchStops(keyword: kw)
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - Stop Detail View

struct StopDetailView: View {
    let stop: SavedStop
    @State private var routes: [RouteEta] = []
    @State private var isLoading = true
    @State private var lastUpdated = Date()
    @State private var errorMsg: String? = nil

    var body: some View {
        List {
            if isLoading {
                HStack { ProgressView(); Text("載入中…").foregroundStyle(.secondary) }
            } else if let err = errorMsg {
                Label(err, systemImage: "exclamationmark.triangle").foregroundStyle(.red)
                    .font(.caption)
            } else if routes.isEmpty {
                Text("暫無班次數據 (stopID: \(stop.stopID))").foregroundStyle(.secondary)
            } else {
                Section("實時到站時間") {
                    ForEach(routes) { r in
                        ETARow(route: r)
                    }
                }
                Section {
                    Text("更新時間：\(lastUpdated.formatted(date: .omitted, time: .standard))")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(stop.label)
        .refreshable { await loadData() }
        .task(id: stop.stopID) { await loadData() }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await loadData() }
                } label: {
                    if isLoading {
                        ProgressView().controlSize(.small)
                    } else {
                        Label("重新整理", systemImage: "arrow.clockwise")
                    }
                }
                .disabled(isLoading)
            }
        }
    }

    func loadData() async {
        isLoading = routes.isEmpty
        errorMsg = nil
        do {
            routes = try await KMBAPIClient.routeEtas(for: stop.stopID)
        } catch {
            errorMsg = error.localizedDescription
            routes = []
        }
        lastUpdated = Date()
        isLoading = false
    }
}

// MARK: - ETA Row

struct ETARow: View {
    let route: RouteEta

    var body: some View {
        HStack(spacing: 12) {
            Text(route.route)
                .font(.system(.headline, design: .monospaced))
                .frame(width: 52, alignment: .leading)
            Text(route.dest)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer()
            Text(route.etaText)
                .font(.subheadline.bold())
                .foregroundStyle(urgencyColor)
            if route.etas.count > 1 {
                Text(subsequentText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    var urgencyColor: Color {
        guard let m = route.nextMins else { return .secondary }
        if m <= 2 { return .red }
        if m <= 5 { return .orange }
        return .green
    }

    var subsequentText: String {
        route.etas.dropFirst().compactMap { m -> String? in
            guard let m else { return nil }
            return m <= 0 ? "即將" : "\(m)分"
        }.joined(separator: " / ")
    }
}
