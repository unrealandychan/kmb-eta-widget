import SwiftUI
import CoreLocation

// MARK: - Nearby Stops View

struct NearbyStopsView: View {
    @StateObject private var loc = LocationManager.shared
    @State private var selectedStop: StopWithDistance?
    @State private var radius: Double = 500

    var body: some View {
        Group {
            switch loc.authStatus {
            case .notDetermined:
                permissionPrompt
            case .denied, .restricted:
                deniedView
            default:
                contentView
            }
        }
        .navigationTitle("📍 附近巴士站")
        .onAppear {
            if loc.authStatus == .authorizedAlways {
                loc.startUpdating()
            }
        }
        .sheet(item: $selectedStop) { item in
            NavigationStack {
                StopDetailWithRemindersView(stop: SavedStop(
                    stopID: item.stop.stopID,
                    label: item.stop.nameTc,
                    nameTc: item.stop.nameTc
                ))
            }
        }
    }

    var permissionPrompt: some View {
        VStack(spacing: 24) {
            Image(systemName: "location.circle.fill")
                .font(.system(size: 70))
                .foregroundStyle(.blue)
            Text("需要位置權限")
                .font(.title2.bold())
            Text("讓 App 知道你在哪裡，自動搵最近嘅巴士站")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button("允許使用位置") {
                loc.requestPermission()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding()
    }

    var deniedView: some View {
        VStack(spacing: 20) {
            Image(systemName: "location.slash.fill")
                .font(.system(size: 60))
                .foregroundStyle(.red)
            Text("位置權限被拒絕")
                .font(.title3.bold())
            Text("請去「系統設定 → 私隱 → 位置服務 → KMB Widget」開啟")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button("開啟系統設定") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices") {
                    NSWorkspace.shared.open(url)
                }
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }

    var contentView: some View {
        List {
            Section {
                Picker("搜尋範圍", selection: $radius) {
                    Text("200m").tag(200.0)
                    Text("500m").tag(500.0)
                    Text("1km").tag(1000.0)
                }
                .pickerStyle(.segmented)
                .onChange(of: radius) { _, _ in
                    Task { await loc.findNearbyStops(radiusMeters: radius) }
                }
            }

            if loc.isLoadingStops {
                Section {
                    HStack { ProgressView(); Text("搜尋附近巴士站…").foregroundStyle(.secondary) }
                }
            } else if let error = loc.error {
                Section {
                    Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(.red)
                }
            } else if loc.nearbyStops.isEmpty {
                Section {
                    Text("附近 \(Int(radius))m 內未找到巴士站").foregroundStyle(.secondary)
                }
            } else {
                Section("\(loc.nearbyStops.count) 個巴士站（\(Int(radius))m 內）") {
                    ForEach(loc.nearbyStops) { item in
                        Button { selectedStop = item } label: {
                            NearbyStopRow(item: item)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .refreshable {
            loc.startUpdating()
        }
    }
}

struct NearbyStopRow: View {
    let item: StopWithDistance

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: "bus.fill")
                    .foregroundStyle(.blue)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(item.stop.nameTc).font(.headline)
                Text(item.stop.nameEn).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(item.distanceText)
                    .font(.subheadline.bold())
                    .foregroundStyle(.blue)
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }
}
