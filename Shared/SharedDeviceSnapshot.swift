import Foundation

struct SharedDeviceSnapshot: Codable, Equatable {
    var batteryLevel: Int
    var isCharging: Bool
    var isConnected: Bool
    var modelName: String
    var ncMode: String
    var lastUpdated: Date

    static let placeholder = SharedDeviceSnapshot(
        batteryLevel: 0,
        isCharging: false,
        isConnected: false,
        modelName: "WH-1000XM6",
        ncMode: "Off",
        lastUpdated: .distantPast
    )
}

struct SharedBatterySample: Codable, Identifiable, Hashable {
    let id: Int64
    let timestamp: Date
    let level: Int
    let charging: Bool
    let ncMode: String
}
