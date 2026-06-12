import SwiftUI

struct SmartProfilesView: View {
    @EnvironmentObject private var store: DeviceStore
    @ObservedObject private var profileStore = ANCProfileStore.shared
    @ObservedObject private var profileEngine = ProfileEngine.shared
    @ObservedObject private var contextMonitor = ContextMonitor.shared
    @State private var editingRule: ANCProfileRule?
    @State private var isCreatingRule = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("ANC Profiles")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Toggle("", isOn: $profileStore.isEnabled)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }

            if profileStore.isEnabled {
                contextCard
                activeProfileCard
                rulesList
            } else {
                Text("Automatically switch ANC based on Wi‑Fi, location, calendar, and the app you're using.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .sheet(item: $editingRule) { rule in
            ANCProfileEditorSheet(rule: rule, isNew: isCreatingRule) { saved in
                if isCreatingRule {
                    profileStore.addRule(saved)
                } else {
                    profileStore.updateRule(saved)
                }
                profileEngine.evaluateNow()
            }
        }
        .onChange(of: editingRule) { _, newValue in
            if newValue == nil {
                isCreatingRule = false
            }
        }
        .onAppear {
            contextMonitor.requestPermissionsIfNeeded()
        }
    }

    private var contextCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Current Context")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                contextTile(icon: "wifi", title: "Wi‑Fi", value: wifiDisplayValue)
                contextTile(icon: "location.fill", title: "Location", value: locationDisplayValue)
                contextTile(icon: "calendar", title: "Meeting", value: meetingDisplayValue)
                contextTile(icon: "macwindow", title: "App", value: appDisplayValue)
            }
        }
        .padding(10)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 10))
    }

    private var wifiDisplayValue: String {
        switch contextMonitor.locationAuthorization {
        case .notDetermined: return "Allow location access"
        case .denied, .restricted: return "Location access off"
        case .authorized:
            return contextMonitor.snapshot.wifiSSID ?? "No Wi‑Fi detected"
        }
    }

    private var locationDisplayValue: String {
        switch contextMonitor.locationAuthorization {
        case .notDetermined: return "Allow location access"
        case .denied, .restricted: return "Location access off"
        case .authorized:
            return contextMonitor.snapshot.locationLabel ?? "Locating…"
        }
    }

    private var meetingDisplayValue: String {
        switch contextMonitor.calendarAuthorization {
        case .notDetermined: return "Allow calendar access"
        case .writeOnly: return "Full calendar access needed"
        case .denied: return "Calendar access off"
        case .authorized:
            let snapshot = contextMonitor.snapshot
            if snapshot.isInMeeting {
                return snapshot.activeMeetingTitle ?? "In progress"
            }
            if let title = snapshot.nextMeetingTitle, let start = snapshot.nextMeetingStart {
                let time = Self.meetingTimeFormatter.string(from: start)
                if start.timeIntervalSinceNow <= 15 * 60 {
                    let minutes = max(1, Int(start.timeIntervalSinceNow / 60))
                    return "\(title) · starts in \(minutes)m"
                }
                return "\(title) · \(time)"
            }
            return "None"
        }
    }

    private static let meetingTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()

    private var appDisplayValue: String {
        contextMonitor.snapshot.activeAppName ?? "Unknown"
    }

    private func contextTile(icon: String, title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: icon)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var activeProfileCard: some View {
        HStack(spacing: 10) {
            Image(systemName: profileEngine.activeRule == nil ? "circle.dashed" : "checkmark.circle.fill")
                .foregroundStyle(profileEngine.activeRule == nil ? Color.secondary : Color.green)
            VStack(alignment: .leading, spacing: 2) {
                Text(profileEngine.activeRule?.name ?? "No matching profile")
                    .font(.caption.weight(.semibold))
                if let rule = profileEngine.activeRule {
                    Text(rule.profileSummary)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button("Refresh") { profileEngine.evaluateNow(force: true) }
                .font(.caption)
                .buttonStyle(.borderless)
        }
        .padding(10)
        .background(.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }

    private var rulesList: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Rules")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    isCreatingRule = true
                    editingRule = ANCProfileRule(
                        id: UUID(),
                        name: "New Profile",
                        enabled: true,
                        priority: 50,
                        trigger: ProfileTrigger(type: .wifi, pattern: ""),
                        profile: .ancMax
                    )
                } label: {
                    Label("Add", systemImage: "plus")
                }
                .font(.caption)
                .buttonStyle(.borderless)

                Button("Reset Defaults") { profileStore.resetToDefaults() }
                    .font(.caption2)
                    .buttonStyle(.borderless)
            }

            ForEach(profileStore.rules.sorted { $0.priority > $1.priority }) { rule in
                ruleRow(rule)
            }
        }
    }

    private func ruleRow(_ rule: ANCProfileRule) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: rule.trigger.type.icon)
                    .foregroundStyle(.secondary)
                    .frame(width: 16)
                Text(rule.name)
                    .font(.caption.weight(.semibold))
                if rule.isBuiltIn {
                    Text("Built-in")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.quaternary.opacity(0.5), in: Capsule())
                }
                Spacer()
                Text("P\(rule.priority)")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.tertiary)

                Button {
                    isCreatingRule = false
                    editingRule = rule
                } label: {
                    Image(systemName: "pencil")
                }
                .buttonStyle(.borderless)
                .font(.caption)
                .help("Edit profile")

                if profileStore.canDelete(rule) {
                    Button(role: .destructive) {
                        profileStore.deleteRule(rule.id)
                        profileEngine.evaluateNow()
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                    .font(.caption)
                    .help("Delete profile")
                }

                Toggle("", isOn: Binding(
                    get: { rule.enabled },
                    set: { profileStore.setRuleEnabled(rule.id, enabled: $0) }
                ))
                .toggleStyle(.switch)
                .labelsHidden()
                .controlSize(.mini)
            }
            Text(rule.triggerSummary)
                .font(.caption2)
                .foregroundStyle(.secondary)

            Text(rule.profileSummary)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(10)
        .background(
            profileEngine.activeRule?.id == rule.id ? Color.blue.opacity(0.1) : Color.clear,
            in: RoundedRectangle(cornerRadius: 10)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(.quaternary.opacity(0.5), lineWidth: 1)
        )
    }
}

private extension ANCProfileRule {
    var profileSummary: String {
        let mode = NCMode(rawValue: profile.ncMode)?.title ?? "ANC"
        if mode == "Ambient" {
            let voice = profile.focusOnVoice ? " · Voice" : ""
            return "\(mode) L\(profile.ambientLevel)\(voice)"
        }
        return mode
    }
}
