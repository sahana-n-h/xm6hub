import SwiftUI

struct SoundControlsView: View {
    @EnvironmentObject private var store: DeviceStore

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Sound Control", systemImage: "waveform")
                .font(.subheadline.weight(.semibold))

            Picker("Mode", selection: Binding(
                get: { store.ncMode },
                set: { store.setNCMode($0) }
            )) {
                ForEach(NCMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            if store.ncMode == .ambient {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Ambient Level")
                            .font(.caption)
                        Spacer()
                        Text("\(store.ambientLevel)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    Slider(
                        value: Binding(
                            get: { Double(store.ambientLevel) },
                            set: { store.setAmbientLevel(Int($0.rounded())) }
                        ),
                        in: 1...20,
                        step: 1
                    )
                }

                Toggle("Voice Passthrough", isOn: Binding(
                    get: { store.focusOnVoice },
                    set: { store.setFocusOnVoice($0) }
                ))

                Toggle("Auto Ambient Sound", isOn: Binding(
                    get: { store.autoAmbientEnabled },
                    set: { store.setAutoAmbientEnabled($0) }
                ))

                if store.autoAmbientEnabled {
                    Picker("Noise Adaptation", selection: Binding(
                        get: { store.noiseAdaptiveSensitivity },
                        set: { store.setNoiseAdaptiveSensitivity($0) }
                    )) {
                        Text("Standard").tag(0)
                        Text("High").tag(1)
                        Text("Low").tag(2)
                    }
                    .pickerStyle(.segmented)
                }
            }
        }
    }
}
