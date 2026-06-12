import SwiftUI

/// Full control center — opens as a dedicated window (primary UI).
struct ControlCenterView: View {
    @EnvironmentObject private var store: DeviceStore
    @ObservedObject private var contextMonitor = ContextMonitor.shared

    var body: some View {
        VStack(spacing: 0) {
            DeviceHeaderView()
                .padding()

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if !store.isConnected {
                        ConnectionStatusView()
                    }

                    if shouldShowPermissionsBanner {
                        permissionsBanner
                    }

                    Group {
                        SmartProfilesView()
                        BatteryChartView()
                        PlaybackControlsView()
                        SoundControlsView()
                        MultipointView()
                    }
                    .disabled(!store.isConnected)
                    .opacity(store.isConnected ? 1 : 0.45)
                }
                .padding()
            }

            Divider()

            FooterView()
                .padding(.horizontal)
                .padding(.vertical, 10)
        }
        .frame(width: 420)
        .frame(minHeight: 520)
        .onAppear {
            contextMonitor.requestPermissionsIfNeeded()
        }
    }

    private var permissionsBanner: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !contextMonitor.locationAuthorization.isAuthorized {
                permissionRow(
                    title: "Location Access",
                    message: contextMonitor.locationAuthorization.statusMessage,
                    allowTitle: "Allow Location",
                    settingsTitle: "Open Location Settings",
                    isNotDetermined: contextMonitor.locationAuthorization == .notDetermined,
                    allowAction: { contextMonitor.requestLocationAccessIfNeeded() },
                    settingsAction: { contextMonitor.openLocationSettings() }
                )
            }

            if !contextMonitor.calendarAuthorization.isAuthorized {
                permissionRow(
                    title: "Calendar Access",
                    message: contextMonitor.calendarAuthorization.statusMessage,
                    allowTitle: "Allow Calendar",
                    settingsTitle: "Open Calendar Settings",
                    isNotDetermined: contextMonitor.calendarAuthorization == .notDetermined,
                    allowAction: { contextMonitor.requestCalendarAccessIfNeeded() },
                    settingsAction: { contextMonitor.openCalendarSettings() }
                )
            }
        }
        .padding(12)
        .background(.yellow.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
    }

    private func permissionRow(
        title: String,
        message: String,
        allowTitle: String,
        settingsTitle: String,
        isNotDetermined: Bool,
        allowAction: @escaping () -> Void,
        settingsAction: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: "exclamationmark.triangle")
                .font(.subheadline.weight(.semibold))
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
            if isNotDetermined {
                Button(allowTitle, action: allowAction)
                    .buttonStyle(.borderedProminent)
            } else {
                Button(settingsTitle, action: settingsAction)
                    .buttonStyle(.bordered)
            }
        }
    }

    private var shouldShowPermissionsBanner: Bool {
        !contextMonitor.locationAuthorization.isAuthorized || !contextMonitor.calendarAuthorization.isAuthorized
    }
}

/// Compact popover content (legacy fallback).
struct MenuBarView: View {
    @EnvironmentObject private var store: DeviceStore

    var body: some View {
        ControlCenterView()
            .environmentObject(store)
    }
}

struct ConnectionStatusView: View {
    @EnvironmentObject private var store: DeviceStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(store.statusMessage, systemImage: store.isConnecting ? "dot.radiowaves.left.and.right" : "exclamationmark.triangle")
                .foregroundStyle(store.isConnecting ? .blue : .orange)

            Text("Connect your WH-1000XM6 via Bluetooth. XM6 Hub will connect automatically.")
                .font(.caption)
                .foregroundStyle(.secondary)

            if !store.pairedDevices.isEmpty {
                Text("Paired devices")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                ForEach(store.pairedDevices, id: \.self) { device in
                    Text(device)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }
}

struct FooterView: View {
    @EnvironmentObject private var store: DeviceStore

    var body: some View {
        HStack {
            Toggle("Launch at Login", isOn: Binding(
                get: { store.launchAtLogin },
                set: { store.setLaunchAtLogin($0) }
            ))
            .toggleStyle(.checkbox)
            .font(.caption)

            Spacer()

            Button("Quit") { NSApplication.shared.terminate(nil) }
                .font(.caption)
        }
    }
}
