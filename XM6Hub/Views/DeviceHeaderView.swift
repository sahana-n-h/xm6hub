import SwiftUI

struct DeviceHeaderView: View {
    @EnvironmentObject private var store: DeviceStore

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.blue.opacity(0.25), .purple.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 52, height: 52)
                Image(systemName: store.isCharging ? "battery.100percent.bolt" : store.menuBarBatterySymbol)
                    .font(.title2)
                    .symbolRenderingMode(.hierarchical)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(store.modelName)
                    .font(.headline)
                HStack(spacing: 8) {
                    if store.isConnected {
                        Text("\(store.batteryLevel)%")
                            .font(.title3.weight(.semibold))
                            .monospacedDigit()
                        Text("FW \(store.firmwareVersion)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if store.menuBarShowsBattery {
                        Text("\(store.menuBarDisplayLevel)% (cached)")
                            .font(.title3.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                        Text(store.statusMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    } else {
                        Text(store.statusMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                if store.isConnected {
                    Text("\(store.codecName) · Sound pressure \(store.soundPressure) dB")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
    }
}
