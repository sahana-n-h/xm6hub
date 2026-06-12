import Foundation
import CoreWLAN
import CoreLocation
import EventKit
import AppKit

enum LocationAuthorizationState: Equatable {
    case notDetermined
    case authorized
    case denied
    case restricted

    var isAuthorized: Bool { self == .authorized }

    var statusMessage: String {
        switch self {
        case .notDetermined:
            return "Location access is needed for Wi‑Fi names and location-based profiles."
        case .authorized:
            return ""
        case .denied:
            return "Location access is off. Enable it in System Settings → Privacy & Security → Location Services → XM6 Hub."
        case .restricted:
            return "Location access is restricted on this Mac."
        }
    }
}

enum CalendarAuthorizationState: Equatable {
    case notDetermined
    case authorized
    case writeOnly
    case denied

    var isAuthorized: Bool { self == .authorized }

    var statusMessage: String {
        switch self {
        case .notDetermined:
            return "Calendar access is needed to detect meetings and apply meeting profiles."
        case .authorized:
            return ""
        case .writeOnly:
            return "XM6 Hub can add events but cannot read your calendar. Enable full access in System Settings → Privacy & Security → Calendars → XM6 Hub."
        case .denied:
            return "Calendar access is off. Enable it in System Settings → Privacy & Security → Calendars → XM6 Hub."
        }
    }
}

@MainActor
final class ContextMonitor: NSObject, ObservableObject, CLLocationManagerDelegate, CWEventDelegate {
    static let shared = ContextMonitor()

    @Published private(set) var snapshot: ContextSnapshot = .empty
    @Published private(set) var locationAuthorization: LocationAuthorizationState = .notDetermined
    @Published private(set) var calendarAuthorization: CalendarAuthorizationState = .notDetermined

    var currentLocation: CLLocation? {
        guard locationAuthorization.isAuthorized else { return nil }
        return locationManager.location
    }

    var onUpdate: ((ContextSnapshot) -> Void)?

    private let locationManager = CLLocationManager()
    private let eventStore = EKEventStore()
    private let geocoder = CLGeocoder()
    private var pollTimer: Timer?
    private var calendarAccess = false
    private var lastGeocodedCoordinate: CLLocationCoordinate2D?
    private var lastGeocodedLabel: String?

    private override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        updateAuthorizationState(from: locationManager.authorizationStatus)
        updateCalendarAuthorization(from: EKEventStore.authorizationStatus(for: .event))
        startMonitoring()
    }

    func requestPermissionsIfNeeded() {
        requestLocationAccessIfNeeded()
        requestCalendarAccessIfNeeded()
        refresh()
    }

    func requestLocationAccessIfNeeded() {
        updateAuthorizationState(from: locationManager.authorizationStatus)

        switch locationAuthorization {
        case .notDetermined:
            NSApplication.shared.activate(ignoringOtherApps: true)
            locationManager.requestWhenInUseAuthorization()
        case .authorized:
            locationManager.startUpdatingLocation()
            if locationManager.location == nil {
                locationManager.requestLocation()
            }
            refresh()
        case .denied, .restricted:
            refresh()
        }
    }

    func requestCalendarAccessIfNeeded() {
        let status = EKEventStore.authorizationStatus(for: .event)
        updateCalendarAuthorization(from: status)

        switch calendarAuthorization {
        case .notDetermined:
            NSApplication.shared.activate(ignoringOtherApps: true)
            eventStore.requestFullAccessToEvents { [weak self] granted, _ in
                Task { @MainActor in
                    guard let self else { return }
                    self.updateCalendarAuthorization(from: EKEventStore.authorizationStatus(for: .event))
                    self.calendarAccess = granted
                    self.refresh()
                }
            }
        case .authorized:
            calendarAccess = true
            refresh()
        case .writeOnly:
            calendarAccess = false
            NSApplication.shared.activate(ignoringOtherApps: true)
            eventStore.requestFullAccessToEvents { [weak self] granted, _ in
                Task { @MainActor in
                    guard let self else { return }
                    self.updateCalendarAuthorization(from: EKEventStore.authorizationStatus(for: .event))
                    self.calendarAccess = granted
                    self.refresh()
                }
            }
        case .denied:
            calendarAccess = false
            refresh()
        }
    }

    func openLocationSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices") {
            NSWorkspace.shared.open(url)
        }
    }

    func openCalendarSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
            NSWorkspace.shared.open(url)
        }
    }

    func startMonitoring() {
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
            }
        }
        if let timer = pollTimer {
            RunLoop.main.add(timer, forMode: .common)
        }

        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(appDidActivate),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(calendarDidChange),
            name: .EKEventStoreChanged,
            object: eventStore
        )

        let wifiClient = CWWiFiClient.shared()
        wifiClient.delegate = self
        wifiClient.startMonitoringEvent(with: .ssidDidChange)
        if locationAuthorization.isAuthorized {
            locationManager.startUpdatingLocation()
        }
        refresh()
    }

    @objc private func appDidActivate() {
        refresh()
    }

    @objc private func calendarDidChange() {
        refresh()
    }

    nonisolated func ssidDidChangeForWiFiInterface(withName interfaceName: String) {
        Task { @MainActor in
            refresh()
        }
    }

    func refresh() {
        let app = NSWorkspace.shared.frontmostApplication
        let ssid = currentWiFiSSID()
        let meeting = meetingSnapshot()

        var label = lastGeocodedLabel
        if let location = currentLocation {
            reverseGeocodeIfNeeded(location)
            label = lastGeocodedLabel ?? coordinateLabel(for: location)
        }

        let newSnapshot = ContextSnapshot(
            wifiSSID: ssid,
            locationLabel: label,
            isInMeeting: meeting.isInMeeting,
            activeMeetingTitle: meeting.activeTitle,
            nextMeetingTitle: meeting.nextTitle,
            nextMeetingStart: meeting.nextStart,
            activeAppBundleID: app?.bundleIdentifier,
            activeAppName: app?.localizedName ?? app?.bundleIdentifier,
            updatedAt: Date()
        )
        let contextChanged = newSnapshot != snapshot
        snapshot = newSnapshot
        if contextChanged {
            onUpdate?(newSnapshot)
        }
    }

    private func coordinateLabel(for location: CLLocation) -> String {
        String(format: "%.4f, %.4f", location.coordinate.latitude, location.coordinate.longitude)
    }

    private func currentWiFiSSID() -> String? {
        guard locationAuthorization.isAuthorized else { return nil }
        guard let interface = CWWiFiClient.shared().interface() else { return nil }
        return interface.ssid()
    }

    private struct MeetingSnapshot {
        var isInMeeting = false
        var activeTitle: String?
        var nextTitle: String?
        var nextStart: Date?
    }

    private func meetingSnapshot(now: Date = Date()) -> MeetingSnapshot {
        guard calendarAccess else { return MeetingSnapshot() }

        let windowStart = now.addingTimeInterval(-900)
        let windowEnd = now.addingTimeInterval(24 * 3600)
        let predicate = eventStore.predicateForEvents(withStart: windowStart, end: windowEnd, calendars: nil)
        let events = eventStore.events(matching: predicate)
            .filter { !$0.isAllDay }
            .sorted { $0.startDate < $1.startDate }

        if let active = events.first(where: { $0.startDate <= now && now < $0.endDate }) {
            return MeetingSnapshot(
                isInMeeting: true,
                activeTitle: active.title.isEmpty ? "Untitled Meeting" : active.title
            )
        }

        if let next = events.first(where: { $0.startDate > now }) {
            return MeetingSnapshot(
                nextTitle: next.title.isEmpty ? "Untitled Meeting" : next.title,
                nextStart: next.startDate
            )
        }

        return MeetingSnapshot()
    }

    private func reverseGeocodeIfNeeded(_ location: CLLocation) {
        let coordinate = location.coordinate
        if let last = lastGeocodedCoordinate {
            let previous = CLLocation(latitude: last.latitude, longitude: last.longitude)
            if location.distance(from: previous) < 200, lastGeocodedLabel != nil { return }
        }

        lastGeocodedCoordinate = coordinate
        geocoder.cancelGeocode()
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
            Task { @MainActor in
                guard let self else { return }
                if let place = placemarks?.first {
                    let parts = [place.name, place.subLocality, place.locality].compactMap { $0 }.filter { !$0.isEmpty }
                    self.lastGeocodedLabel = parts.first
                } else if error != nil {
                    self.lastGeocodedLabel = self.coordinateLabel(for: location)
                }
                self.refresh()
            }
        }
    }

    private func updateAuthorizationState(from status: CLAuthorizationStatus) {
        switch status {
        case .notDetermined:
            locationAuthorization = .notDetermined
        case .authorizedAlways, .authorizedWhenInUse:
            locationAuthorization = .authorized
        case .denied:
            locationAuthorization = .denied
        case .restricted:
            locationAuthorization = .restricted
        @unknown default:
            locationAuthorization = .denied
        }
    }

    private func updateCalendarAuthorization(from status: EKAuthorizationStatus) {
        switch status {
        case .fullAccess, .authorized:
            calendarAuthorization = .authorized
            calendarAccess = true
        case .writeOnly:
            calendarAuthorization = .writeOnly
            calendarAccess = false
        case .notDetermined:
            calendarAuthorization = .notDetermined
            calendarAccess = false
        default:
            calendarAuthorization = .denied
            calendarAccess = false
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            if let location = locations.last {
                reverseGeocodeIfNeeded(location)
            }
            refresh()
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            updateAuthorizationState(from: manager.authorizationStatus)
            if locationAuthorization.isAuthorized {
                manager.startUpdatingLocation()
                if manager.location == nil {
                    manager.requestLocation()
                }
            }
            refresh()
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            refresh()
        }
    }
}
