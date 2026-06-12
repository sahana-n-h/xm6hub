import SwiftUI

struct MultipointView: View {
    @EnvironmentObject private var store: DeviceStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Multipoint", systemImage: "point.3.connected.trianglepath.dotted")
                .font(.subheadline.weight(.semibold))

            if store.multipointDevices.isEmpty {
                Text("Enable “Connect to 2 devices simultaneously” in Sony Sound Connect to manage multipoint here.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(store.multipointDevices) { device in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(device.name)
                                    .font(.subheadline.weight(device.isActive ? .semibold : .regular))
                                if device.isActive {
                                    Text("Active")
                                        .font(.caption2.weight(.semibold))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(.blue.opacity(0.15), in: Capsule())
                                }
                            }
                            Text(device.macAddress)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Circle()
                            .fill(device.connected ? Color.green : Color.secondary.opacity(0.4))
                            .frame(width: 8, height: 8)

                        Menu {
                            if !device.isActive {
                                Button("Switch Audio Here") {
                                    store.switchMultipoint(to: device.macAddress)
                                }
                            }
                            if device.connected {
                                Button("Disconnect") {
                                    store.disconnectMultipoint(device.macAddress)
                                }
                            } else {
                                Button("Connect") {
                                    store.connectMultipoint(device.macAddress)
                                }
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                        .menuStyle(.borderlessButton)
                    }
                    .padding(10)
                    .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }
}
