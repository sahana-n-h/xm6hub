import SwiftUI

struct PlaybackControlsView: View {
    @EnvironmentObject private var store: DeviceStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Now Playing", systemImage: "music.note")
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                Text(store.trackTitle.isEmpty ? "Nothing playing" : store.trackTitle)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if !store.trackArtist.isEmpty {
                    Text(store.trackArtist)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                if !store.trackAlbum.isEmpty {
                    Text(store.trackAlbum)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 16) {
                Button(action: store.skipPrevious) {
                    Image(systemName: "backward.fill")
                }
                Button(action: store.togglePlayback) {
                    Image(systemName: store.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.title2)
                }
                Button(action: store.skipNext) {
                    Image(systemName: "forward.fill")
                }
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)

            HStack {
                Image(systemName: "speaker.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Slider(
                    value: Binding(
                        get: { Double(store.volume) },
                        set: { store.setVolume(Int($0.rounded())) }
                    ),
                    in: 0...30,
                    step: 1
                )
                Text("\(store.volume)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 24)
            }
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
