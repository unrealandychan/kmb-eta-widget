import SwiftUI
import WidgetKit

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
                Text("Widget 每 5 分鐘自動更新。在主畫面長按 Widget 可選擇顯示哪個巴士站。")
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
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Custom search bar — always focusable on macOS
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("輸入地區或站名，例如：旺角", text: $query)
                    .textFieldStyle(.plain)
                    .focused($searchFocused)
                    .onChange(of: query) { _, new in
                        guard new.count >= 2 else { results = []; return }
                        Task { await search(new) }
                    }
                if !query.isEmpty {
                    Button { query = ""; results = [] } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(10)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
            .padding([.horizontal, .top], 16)
            .padding(.bottom, 8)

            Divider()

            List {
                if isLoading {
                    HStack {
                        ProgressView()
                        Text("搜尋中…").foregroundStyle(.secondary)
                    }
                } else if let error {
                    Text("❌ \(error)").foregroundStyle(.red)
                } else if results.isEmpty && query.count >= 2 {
                    Text("找不到相關巴士站").foregroundStyle(.secondary)
                } else {
                    ForEach(results) { stop in
                        Button {
                            onSelect(stop)
                            dismiss()
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(stop.nameTc).font(.headline).foregroundStyle(.primary)
                                Text(stop.nameEn).font(.caption).foregroundStyle(.secondary)
                                Text(stop.stopID).font(.caption2).foregroundStyle(.tertiary)
                            }
                            .padding(.vertical, 2)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .listStyle(.plain)

            Divider()
            HStack {
                Spacer()
                Button("取消") { dismiss() }
                    .keyboardShortcut(.escape, modifiers: [])
                    .padding(.trailing, 16)
            }
            .padding(.vertical, 10)
        }
        .frame(minWidth: 420, minHeight: 480)
        .onAppear {
            // Delay slightly to ensure sheet is fully presented before focusing
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                searchFocused = true
            }
        }
    }

    func search(_ kw: String) async {
        isLoading = true; error = nil
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

    var body: some View {
        List {
            if isLoading {
                HStack { ProgressView(); Text("載入中…").foregroundStyle(.secondary) }
            } else if routes.isEmpty {
                Text("暫無班次數據").foregroundStyle(.secondary)
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
        .task { await loadData() }
    }

    func loadData() async {
        isLoading = routes.isEmpty
        routes = (try? await KMBAPIClient.routeEtas(for: stop.stopID)) ?? []
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
