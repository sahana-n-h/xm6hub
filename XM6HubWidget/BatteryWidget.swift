import WidgetKit
import SwiftUI

@main
struct XM6HubWidgetBundle: WidgetBundle {
    var body: some Widget {
        BatteryWidget()
    }
}

struct BatteryWidget: Widget {
    let kind = "BatteryWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BatteryWidgetProvider()) { entry in
            BatteryWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("XM6 Battery")
        .description("Battery level and history for your WH-1000XM6.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct BatteryWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: SharedDeviceSnapshot
    let samples: [SharedBatterySample]
}

struct BatteryWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> BatteryWidgetEntry {
        BatteryWidgetEntry(
            date: Date(),
            snapshot: SharedDeviceSnapshot(
                batteryLevel: 72,
                isCharging: false,
                isConnected: true,
                modelName: "WH-1000XM6",
                ncMode: "ANC",
                lastUpdated: Date()
            ),
            samples: previewSamples
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (BatteryWidgetEntry) -> Void) {
        completion(makeEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BatteryWidgetEntry>) -> Void) {
        let entry = makeEntry()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date().addingTimeInterval(900)
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }

    private func makeEntry() -> BatteryWidgetEntry {
        let store = SharedBatteryStore.shared
        return BatteryWidgetEntry(
            date: Date(),
            snapshot: store.snapshot,
            samples: store.samples(limit: 48)
        )
    }

    private var previewSamples: [SharedBatterySample] {
        let now = Date()
        return (0..<12).map { index in
            SharedBatterySample(
                id: Int64(index),
                timestamp: now.addingTimeInterval(TimeInterval(-index * 900)),
                level: 90 - index * 2,
                charging: false,
                ncMode: "ANC"
            )
        }.reversed()
    }
}
