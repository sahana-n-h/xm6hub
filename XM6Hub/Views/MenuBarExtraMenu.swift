import SwiftUI

struct MenuBarExtraMenu: View {
    @EnvironmentObject private var store: DeviceStore

    var body: some View {
        if store.menuBarShowsBattery {
            Text("\(store.menuBarDisplayLevel)% · \(store.modelName)")
        } else {
            Text("XM6 Hub")
        }

        Divider()

        Button("Open Control Center…") {
            ControlCenterWindowOpener.openControlCenter()
        }

        Divider()

        Button("Quit XM6 Hub") { NSApplication.shared.terminate(nil) }
    }
}
