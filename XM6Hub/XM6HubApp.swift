import SwiftUI

@main
struct XM6HubApp: App {
    @StateObject private var store = DeviceStore()

    var body: some Scene {
        MenuBarExtra {
            LaunchHelper()
            MenuBarExtraMenu()
                .environmentObject(store)
        } label: {
            MenuBarLabel(store: store)
        }
        .menuBarExtraStyle(.menu)

        WindowGroup(id: "control-center") {
            ControlCenterView()
                .environmentObject(store)
                .background(WindowOpenerRegistration())
        }
        .defaultSize(width: 420, height: 720)
        .windowResizability(.contentMinSize)

        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}

@MainActor
enum ControlCenterWindowOpener {
    static func openControlCenter() {
        WindowRouter.open("control-center")
    }
}

struct LaunchHelper: View {
    var body: some View {
        WindowOpenerRegistration()
            .onAppear {
                guard XM6HubApp.shouldAutoOpenControlCenter else { return }
                XM6HubApp.markControlCenterShown()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    WindowRouter.open("control-center")
                }
            }
    }
}

extension XM6HubApp {
    static func markControlCenterShown() {
        UserDefaults.standard.set(true, forKey: "didShowControlCenterOnce")
    }

    static var shouldAutoOpenControlCenter: Bool {
        !UserDefaults.standard.bool(forKey: "didShowControlCenterOnce")
    }
}

struct MenuBarLabel: View {
    @ObservedObject var store: DeviceStore

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: store.menuBarBatterySymbol)
            if store.menuBarShowsBattery {
                Text("\(store.menuBarDisplayLevel)%")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .monospacedDigit()
            }
        }
        .help("XM6 Hub — click for menu, then Open Control Center")
    }
}
