import SwiftUI
import Charts

struct BatteryWidgetView: View {
    let entry: BatteryWidgetEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .systemLarge:
            largeView
        case .systemMedium:
            mediumView
        default:
            smallView
        }
    }

    private var smallView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: batterySymbol)
                    .font(.title2)
                    .symbolRenderingMode(.hierarchical)
                Spacer()
                if entry.snapshot.isConnected {
                    Text("\(entry.snapshot.batteryLevel)%")
                        .font(.title.weight(.bold))
                        .monospacedDigit()
                }
            }
            Text(entry.snapshot.modelName)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
            if entry.snapshot.isConnected {
                Text("\(entry.snapshot.ncMode) · updated \(entry.snapshot.lastUpdated, style: .relative) ago")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            } else {
                Text("Not connected")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding()
    }

    private var mediumView: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Label("XM6 Hub", systemImage: batterySymbol)
                    .font(.headline)
                if entry.snapshot.isConnected {
                    Text("\(entry.snapshot.batteryLevel)%")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    Text(entry.snapshot.ncMode)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("—")
                        .font(.largeTitle.weight(.bold))
                    Text("Open XM6 Hub")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 110, alignment: .leading)

            if entry.samples.count >= 2 {
                Chart(entry.samples) { sample in
                    LineMark(
                        x: .value("Time", sample.timestamp),
                        y: .value("Battery", sample.level)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(.blue)
                }
                .chartYScale(domain: 0...100)
                .chartXAxis(.hidden)
                .chartYAxis {
                    AxisMarks(position: .leading, values: [0, 50, 100]) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let level = value.as(Int.self) {
                                Text("\(level)")
                                    .font(.caption2)
                            }
                        }
                    }
                }
            } else {
                Spacer()
                Text("Collecting history…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
        .padding()
    }

    private var largeView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.snapshot.modelName)
                        .font(.headline)
                    if entry.snapshot.isConnected {
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text("\(entry.snapshot.batteryLevel)%")
                                .font(.system(size: 42, weight: .bold, design: .rounded))
                                .monospacedDigit()
                            if entry.snapshot.isCharging {
                                Image(systemName: "bolt.fill")
                                    .foregroundStyle(.yellow)
                            }
                        }
                        Text("\(entry.snapshot.ncMode) mode")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Not connected")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Image(systemName: batterySymbol)
                    .font(.system(size: 36))
                    .symbolRenderingMode(.hierarchical)
            }

            if entry.samples.count >= 2 {
                Chart(entry.samples) { sample in
                    LineMark(
                        x: .value("Time", sample.timestamp),
                        y: .value("Battery", sample.level)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(.blue)

                    AreaMark(
                        x: .value("Time", sample.timestamp),
                        y: .value("Battery", sample.level)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue.opacity(0.35), .blue.opacity(0.05)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
                .chartYScale(domain: 0...100)
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.hour().minute())
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: [0, 25, 50, 75, 100])
                }
                .frame(maxHeight: .infinity)
            } else {
                Spacer()
                Text("Battery history will appear after XM6 Hub runs for a while.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                Spacer()
            }
        }
        .padding()
    }

    private var batterySymbol: String {
        guard entry.snapshot.isConnected else { return "headphones" }
        if entry.snapshot.isCharging { return "battery.100percent.bolt" }
        switch entry.snapshot.batteryLevel {
        case 76...100: return "battery.100"
        case 51...75: return "battery.75"
        case 26...50: return "battery.50"
        case 11...25: return "battery.25"
        default: return "battery.0"
        }
    }
}
