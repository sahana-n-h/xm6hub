import Foundation

typealias BatterySample = SharedBatterySample

enum BatteryHistoryStore {
    static var shared: SharedBatteryStore { SharedBatteryStore.shared }
}
