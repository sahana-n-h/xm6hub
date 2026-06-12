import SwiftUI

@MainActor
enum WindowRouter {
    private static var openWindowAction: OpenWindowAction?

    static func register(_ action: OpenWindowAction) {
        openWindowAction = action
    }

    static func open(_ id: String) {
        NSApplication.shared.activate(ignoringOtherApps: true)
        openWindowAction?(id: id)
    }
}

/// Captures `openWindow` so menu commands and Control Center buttons can open other windows reliably.
struct WindowOpenerRegistration: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .onAppear {
                WindowRouter.register(openWindow)
            }
    }
}
