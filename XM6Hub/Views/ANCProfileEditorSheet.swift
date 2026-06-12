import SwiftUI

struct ANCProfileEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: ANCProfileRule
    let isNew: Bool
    let onSave: (ANCProfileRule) -> Void

    init(rule: ANCProfileRule, isNew: Bool, onSave: @escaping (ANCProfileRule) -> Void) {
        _draft = State(initialValue: rule)
        self.isNew = isNew
        self.onSave = onSave
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(isNew ? "New Profile" : "Edit Profile")
                    .font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }
            }
            .padding()

            Divider()

            Form {
                Section("Profile") {
                    TextField("Name", text: $draft.name)
                    Stepper(value: $draft.priority, in: 1...200) {
                        Text("Priority: \(draft.priority)")
                    }
                    Toggle("Enabled", isOn: $draft.enabled)
                }

                Section("Trigger") {
                    Picker("Type", selection: $draft.trigger.type) {
                        ForEach(ProfileTriggerType.allCases) { type in
                            Label(type.title, systemImage: type.icon).tag(type)
                        }
                    }
                    if draft.trigger.type != .calendarMeeting {
                        TextField(triggerPlaceholder, text: $draft.trigger.pattern)
                    } else {
                        Text("Applies whenever a calendar meeting is in progress.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Sound") {
                    Picker("Mode", selection: $draft.profile.ncMode) {
                        ForEach(NCMode.allCases) { mode in
                            Text(mode.title).tag(mode.rawValue)
                        }
                    }

                    if draft.profile.ncModeEnum == .ambient {
                        Stepper(value: $draft.profile.ambientLevel, in: 1...20) {
                            Text("Ambient Level: \(draft.profile.ambientLevel)")
                        }
                        Toggle("Voice Passthrough", isOn: $draft.profile.focusOnVoice)
                    }
                }
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                Spacer()
                Button("Save") {
                    onSave(draft)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .frame(width: 380, height: 440)
    }

    private var triggerPlaceholder: String {
        switch draft.trigger.type {
        case .wifi: return "Wi‑Fi name contains…"
        case .location: return "Location name contains…"
        case .calendarMeeting: return ""
        case .activeApp: return "App name contains…"
        }
    }
}
