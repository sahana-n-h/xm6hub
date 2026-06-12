import SwiftUI
import Charts

struct BatteryChartView: View {
    @EnvironmentObject private var store: DeviceStore
    @State private var samples: [BatterySample] = []
    @State private var refreshTimer: Timer?
    @State private var visibleDuration: TimeInterval = 4 * 3600
    @State private var scrollPosition = Date()
    @State private var magnification: CGFloat = 1.0

    private let minVisibleDuration: TimeInterval = 60
    private let maxVisibleDuration: TimeInterval = 7 * 24 * 3600

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Battery History", systemImage: "chart.line.uptrend.xyaxis")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if canInteractWithChart {
                    HStack(spacing: 10) {
                        Button { zoom(by: 1.35) } label: {
                            Image(systemName: "minus.magnifyingglass")
                        }
                        .help("Zoom out")

                        Text(zoomLabel)
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(minWidth: 36)

                        Button { zoom(by: 0.74) } label: {
                            Image(systemName: "plus.magnifyingglass")
                        }
                        .help("Zoom in")
                    }
                    .buttonStyle(.plain)
                }
            }

            if displaySamples.isEmpty {
                Text(emptyMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 90, alignment: .leading)
            } else {
                chart
                    .frame(maxWidth: .infinity)
                    .frame(height: 130)
            }

            if canInteractWithChart {
                Text("Drag to scroll · Pinch or use ± to zoom")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            refresh()
            startRefreshTimer()
            scrollToEnd()
        }
        .onDisappear {
            refreshTimer?.invalidate()
            refreshTimer = nil
        }
        .onChange(of: store.batteryLevel) { _, _ in
            refresh()
            scrollToEnd()
        }
        .onChange(of: store.isConnected) { _, _ in refresh() }
        .onChange(of: samples.count) { _, _ in scrollToEnd() }
    }

    @ViewBuilder
    private var chart: some View {
        let chartView = Chart(displaySamples) { sample in
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

        if canInteractWithChart {
            chartView
                .chartScrollableAxes(.horizontal)
                .chartXVisibleDomain(length: clampedVisibleDuration)
                .chartScrollPosition(x: $scrollPosition)
                .simultaneousGesture(
                    MagnificationGesture()
                        .onChanged { value in
                            let scale = Double(value / magnification)
                            guard scale > 0 else { return }
                            magnification = value
                            visibleDuration = clampDuration(visibleDuration / scale)
                        }
                        .onEnded { _ in
                            magnification = 1.0
                        }
                )
        } else {
            chartView
        }
    }

    private var displaySamples: [BatterySample] {
        if !samples.isEmpty { return samples }
        guard store.isConnected, store.batteryLevel > 0 else { return [] }
        return [
            BatterySample(
                id: -1,
                timestamp: Date().addingTimeInterval(-300),
                level: store.batteryLevel,
                charging: store.isCharging,
                ncMode: store.ncMode.title
            ),
            BatterySample(
                id: -2,
                timestamp: Date(),
                level: store.batteryLevel,
                charging: store.isCharging,
                ncMode: store.ncMode.title
            ),
        ]
    }

    private var dataSpan: TimeInterval? {
        let samples = displaySamples
        guard let first = samples.first?.timestamp,
              let last = samples.last?.timestamp else { return nil }
        let span = last.timeIntervalSince(first)
        return span > 0 ? span : nil
    }

    private var canInteractWithChart: Bool {
        guard let span = dataSpan else { return false }
        return span > minVisibleDuration
    }

    private var clampedVisibleDuration: TimeInterval {
        clampDuration(visibleDuration)
    }

    private var zoomLabel: String {
        let duration = clampedVisibleDuration
        if duration < 2 * 3600 {
            return "\(Int(duration / 60))m"
        }
        if duration < 48 * 3600 {
            return String(format: "%.1fh", duration / 3600)
        }
        return String(format: "%.0fd", duration / (24 * 3600))
    }

    private var emptyMessage: String {
        if store.isConnected {
            return "Waiting for the first battery sample…"
        }
        return "Connect your XM6 to start collecting battery history."
    }

    private func refresh() {
        samples = BatteryHistoryStore.shared.samples(limit: 2000)
    }

    private func startRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { _ in
            refresh()
        }
        if let refreshTimer {
            RunLoop.main.add(refreshTimer, forMode: .common)
        }
    }

    private func zoom(by factor: Double) {
        visibleDuration = clampDuration(visibleDuration * factor)
    }

    private func clampDuration(_ duration: TimeInterval) -> TimeInterval {
        let span = dataSpan ?? duration
        let upperBound = min(maxVisibleDuration, max(span + 60, minVisibleDuration))
        return min(max(duration, minVisibleDuration), upperBound)
    }

    private func scrollToEnd() {
        guard let last = displaySamples.last?.timestamp else { return }
        scrollPosition = last
    }
}
