import SwiftUI
import Combine

// MARK: - macOS Menu Bar App Entry Point

@main
struct KMBMenuBarApp: App {
    @StateObject private var vm = MenuBarViewModel()

    var body: some Scene {
        // MenuBarExtra: native macOS 13+ menu bar item
        MenuBarExtra {
            MenuBarContentView()
                .environmentObject(vm)
        } label: {
            MenuBarLabel()
                .environmentObject(vm)
        }
        .menuBarExtraStyle(.window)   // popover window style (not plain menu)
    }
}

// MARK: - Menu Bar Icon + Countdown Label

struct MenuBarLabel: View {
    @EnvironmentObject var vm: MenuBarViewModel

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "bus.fill")
                .symbolRenderingMode(.hierarchical)

            if vm.stops.isEmpty {
                Text("—")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
            } else {
                // Show up to 2 routes inline: "234 3m  98C 8m"
                ForEach(vm.topRoutes.prefix(2)) { r in
                    Group {
                        Text(r.route).fontWeight(.bold)
                        + Text(" ")
                        + Text(r.shortEta).foregroundColor(r.swiftUIUrgencyColor)
                    }
                    .font(.system(size: 12, weight: .regular, design: .monospaced))
                }
            }
        }
        .padding(.horizontal, 2)
    }
}
