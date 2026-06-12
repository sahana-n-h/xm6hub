import Foundation
import SQLite3

final class SharedBatteryStore {
    static let shared = SharedBatteryStore()

    private var db: OpaquePointer?
    private let defaults: UserDefaults?
    private let dbURL: URL
    private var lastRecordedAt: Date?
    private var lastRecordedLevel: Int?

    var databaseURL: URL { dbURL }

    private init() {
        defaults = UserDefaults(suiteName: AppGroupConstants.suiteName)
        let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: AppGroupConstants.suiteName
        )
        if let container {
            dbURL = container.appendingPathComponent(AppGroupConstants.databaseFileName)
        } else {
            let fallback = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
                .appendingPathComponent("XM6Hub", isDirectory: true)
            try? FileManager.default.createDirectory(at: fallback, withIntermediateDirectories: true)
            dbURL = fallback.appendingPathComponent(AppGroupConstants.databaseFileName)
        }
        openDatabase()
        createTableIfNeeded()
        migrateLegacyDatabaseIfNeeded()
    }

    deinit {
        if db != nil {
            sqlite3_close(db)
        }
    }

    var snapshot: SharedDeviceSnapshot {
        guard let data = defaults?.data(forKey: AppGroupConstants.snapshotKey),
              let decoded = try? JSONDecoder().decode(SharedDeviceSnapshot.self, from: data) else {
            return .placeholder
        }
        return decoded
    }

    func updateSnapshot(_ snapshot: SharedDeviceSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults?.set(data, forKey: AppGroupConstants.snapshotKey)
    }

    func record(level: Int, charging: Bool, ncMode: String, force: Bool = false) {
        guard level > 0 else { return }

        let now = Date()
        if !force,
           let lastAt = lastRecordedAt,
           let lastLevel = lastRecordedLevel,
           now.timeIntervalSince(lastAt) < 60,
           lastLevel == level {
            return
        }

        lastRecordedAt = now
        lastRecordedLevel = level

        let sql = "INSERT INTO battery_samples (timestamp, level, charging, nc_mode) VALUES (?, ?, ?, ?);"
        var statement: OpaquePointer?
        guard let db, sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_double(statement, 1, now.timeIntervalSince1970)
        sqlite3_bind_int(statement, 2, Int32(level))
        sqlite3_bind_int(statement, 3, charging ? 1 : 0)
        sqlite3_bind_text(statement, 4, (ncMode as NSString).utf8String, -1, nil)
        sqlite3_step(statement)
    }

    func samples(limit: Int = 240) -> [SharedBatterySample] {
        let sql = "SELECT id, timestamp, level, charging, nc_mode FROM battery_samples ORDER BY timestamp DESC LIMIT ?;"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_int(statement, 1, Int32(limit))

        var results: [SharedBatterySample] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            let id = sqlite3_column_int64(statement, 0)
            let timestamp = Date(timeIntervalSince1970: sqlite3_column_double(statement, 1))
            let level = Int(sqlite3_column_int(statement, 2))
            let charging = sqlite3_column_int(statement, 3) == 1
            let ncMode = String(cString: sqlite3_column_text(statement, 4))
            results.append(SharedBatterySample(id: id, timestamp: timestamp, level: level, charging: charging, ncMode: ncMode))
        }
        return results.reversed()
    }

    /// Percent per hour based on recent non-charging samples (minimum 2 points, 15+ min span).
    func estimatedDrainRatePercentPerHour() -> Double? {
        let recent = samples(limit: 120).filter { !$0.charging }
        guard recent.count >= 2 else { return nil }

        let oldest = recent.first!
        let newest = recent.last!
        let hours = newest.timestamp.timeIntervalSince(oldest.timestamp) / 3600
        guard hours >= 0.25 else { return nil }

        let delta = Double(newest.level - oldest.level)
        return delta / hours
    }

    /// Project battery level after `hours` using measured drain rate.
    func projectedLevel(afterHours hours: Double, from currentLevel: Int) -> Int? {
        guard let rate = estimatedDrainRatePercentPerHour(), rate < 0 else { return nil }
        let projected = Double(currentLevel) + rate * hours
        return max(0, min(100, Int(projected.rounded())))
    }

    private func openDatabase() {
        let directory = dbURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        if sqlite3_open(dbURL.path, &db) != SQLITE_OK {
            db = nil
        }
    }

    private func createTableIfNeeded() {
        let sql = """
        CREATE TABLE IF NOT EXISTS battery_samples (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp REAL NOT NULL,
            level INTEGER NOT NULL,
            charging INTEGER NOT NULL,
            nc_mode TEXT NOT NULL
        );
        """
        sqlite3_exec(db, sql, nil, nil, nil)
    }

    private func migrateLegacyDatabaseIfNeeded() {
        let legacyURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("XM6Hub/battery-history.sqlite")
        guard legacyURL.path != dbURL.path,
              FileManager.default.fileExists(atPath: legacyURL.path),
              !FileManager.default.fileExists(atPath: dbURL.path) else { return }
        try? FileManager.default.copyItem(at: legacyURL, to: dbURL)
    }
}
