import SwiftUI

// MARK: - Main Popover Content

struct MenuBarContentView: View {
    @EnvironmentObject var vm: MenuBarViewModel
    @State private var showSearch = false
    @State private var expandedStop: String? = nil   // which stop's ETA is expanded

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            stopsList
            Divider()
            footer
        }
        .frame(width: 340)
        .sheet(isPresented: $showSearch) {
            MacStopSearchView { stop in
                vm.addStop(stop)
            }
            .frame(width: 340, height: 440)
        }
    }

    // MARK: Header
    var header: some View {
        HStack {
            Label("九巴到站時間", systemImage: "bus.fill")
                .font(.headline)
            Spacer()
            if vm.isRefreshing {
                ProgressView().controlSize(.small)
            }
            Button { showSearch = true } label: {
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(.blue)
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .help("新增巴士站")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: Stops List
    @ViewBuilder
    var stopsList: some View {
        if vm.stops.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "bus")
                    .font(.system(size: 36))
                    .foregroundStyle(.secondary)
                Text("點擊「+」新增你的巴士站")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(vm.stops) { stop in
                        StopSection(
                            stop: stop,
                            routes: vm.etaByStop[stop.stopID] ?? [],
                            isExpanded: expandedStop == stop.stopID,
                            onToggle: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    expandedStop = expandedStop == stop.stopID ? nil : stop.stopID
                                }
                            },
                            onRemove: { vm.removeStop(id: stop.stopID) }
                        )
                        if stop.stopID != vm.stops.last?.stopID {
                            Divider().padding(.leading, 14)
                        }
                    }
                }
            }
            .frame(maxHeight: 400)
        }
    }

    // MARK: Footer
    var footer: some View {
        HStack {
            if let updated = vm.lastUpdated {
                Text("更新：\(updated.formatted(date: .omitted, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                Task { await vm.refresh() }
            } label: {
                Label("立即更新", systemImage: "arrow.clockwise")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.blue)

            Divider().frame(height: 12)

            Button("退出") { NSApplication.shared.terminate(nil) }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }
}

// MARK: - Per-Stop Section

struct StopSection: View {
    let stop: SavedStop
    let routes: [RouteEta]
    let isExpanded: Bool
    let onToggle: () -> Void
    let onRemove: () -> Void

    // Top 2 routes shown collapsed
    var previewRoutes: [RouteEta] { Array(routes.prefix(2)) }

    var body: some View {
        VStack(spacing: 0) {
            // Stop header row
            Button(action: onToggle) {
                HStack(spacing: 10) {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundStyle(.blue)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(stop.label)
                            .font(.subheadline.bold())
                        if !isExpanded {
                            // Inline preview of next 2 buses
                            inlinePreview
                        }
                    }

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .contextMenu {
                Button("移除此站", role: .destructive) { onRemove() }
            }

            // Expanded ETA list
            if isExpanded {
                VStack(spacing: 0) {
                    if routes.isEmpty {
                        Text("暫無班次數據")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 12)
                    } else {
                        ForEach(routes.prefix(8)) { r in
                            ETAMacRow(route: r)
                            if r.id != routes.prefix(8).last?.id {
                                Divider().padding(.leading, 52)
                            }
                        }
                    }
                }
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    var inlinePreview: some View {
        HStack(spacing: 8) {
            ForEach(previewRoutes) { r in
                HStack(spacing: 3) {
                    Text(r.route)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                    Text(r.shortEta)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(r.swiftUIUrgencyColor)
                }
            }
            if routes.isEmpty {
                Text("載入中…").font(.caption2).foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - ETA Row (macOS)

struct ETAMacRow: View {
    let route: RouteEta

    var body: some View {
        HStack(spacing: 0) {
            // Route badge
            Text(route.route)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(RoundedRectangle(cornerRadius: 5).fill(Color(hex: "#1C4CBF")))
                .frame(width: 52, alignment: .leading)
                .padding(.leading, 14)

            Text(route.dest)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .padding(.leading, 8)

            Spacer()

            // Up to 3 ETAs
            HStack(spacing: 10) {
                ForEach(Array(route.etas.prefix(3).enumerated()), id: \.offset) { idx, m in
                    etaChip(m, primary: idx == 0)
                }
            }
            .padding(.trailing, 14)
        }
        .padding(.vertical, 7)
    }

    @ViewBuilder
    func etaChip(_ mins: Int?, primary: Bool) -> some View {
        let text: String = {
            guard let m = mins else { return "—" }
            if m <= 0 { return "即到" }
            return "\(m) 分"
        }()
        let color: Color = {
            guard let m = mins else { return .secondary }
            if m <= 2 { return .red }
            if m <= 5 { return .orange }
            return .green
        }()

        Text(text)
            .font(.system(size: primary ? 13 : 11,
                          weight: primary ? .bold : .regular,
                          design: .monospaced))
            .foregroundStyle(primary ? color : .secondary)
    }
}

// MARK: - Stop Search (macOS sheet)

struct MacStopSearchView: View {
    var onSelect: (SavedStop) -> Void
    @Environment(\.dismiss) var dismiss
    @State private var query = ""
    @State private var results: [KMBStop] = []
    @State private var isLoading = false
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Search field
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("搜尋巴士站（中文或英文）", text: $query)
                    .textFieldStyle(.plain)
                    .focused($searchFocused)
                    .onSubmit { Task { await search() } }
                if isLoading { ProgressView().controlSize(.small) }
            }
            .padding(10)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(searchFocused ? Color.accentColor : Color.clear, lineWidth: 2))
            .padding(12)
            .onChange(of: query) { _, new in
                guard new.count >= 2 else { results = []; return }
                Task { await search() }
            }

            Divider()

            List(results) { stop in
                Button {
                    let saved = SavedStop(stopID: stop.stopID, label: stop.nameTc, nameTc: stop.nameTc)
                    onSelect(saved)
                    dismiss()
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(stop.nameTc).font(.headline)
                        Text(stop.nameEn).font(.caption).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .listStyle(.plain)

            Divider()
            HStack {
                Spacer()
                Button("取消") { dismiss() }
                    .keyboardShortcut(.escape)
            }
            .padding(10)
        }
        .task {
            try? await Task.sleep(for: .milliseconds(300))
            searchFocused = true
        }
    }

    func search() async {
        isLoading = true
        results = (try? await KMBAPIClient.searchStops(keyword: query)) ?? []
        isLoading = false
    }
}

// MARK: - Color Hex Extension

extension Color {
    init(hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: h).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8)  & 0xFF) / 255
        let b = Double(int         & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
