import SwiftUI

/// The Sound Almanac: mixtapes on a shelf, and the mixer.
///
/// Locked collections are shown, never hidden — but there are two kinds of
/// lock here and they read differently on purpose. A Plus mixtape has a
/// padlock and opens the paywall; a mixtape you simply haven't travelled to
/// says how far away it is. One is a thing to buy, the other is a thing to do,
/// and blurring them would make the journey feel like a sales funnel.
struct SoundStudioView: View {
    @Environment(TimerEngine.self) private var engine
    @Environment(StoreManager.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var showPaywall = false

    var body: some View {
        @Bindable var engine = engine

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    ambienceSection
                    mixerSection
                    ForEach(MusicCatalog.shelf) { collection in
                        shelf(for: collection)
                    }
                }
                .padding()
            }
            .background(Theme.cream.ignoresSafeArea())
            .navigationTitle("Sound Studio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showPaywall) { PaywallView() }
        }
    }

    // MARK: Sections

    private var ambienceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Ambience")
                .font(.headline)
                .foregroundStyle(Theme.bark)
            AmbiencePicker { showPaywall = true }
        }
    }

    @ViewBuilder
    private var mixerSection: some View {
        @Bindable var engine = engine
        let layered = store.hasPlus || LaunchOptions.unlockMusic

        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Mixer")
                    .font(.headline)
                    .foregroundStyle(Theme.bark)
                if !layered {
                    Image(systemName: "lock.fill")
                        .font(.caption2)
                        .foregroundStyle(Theme.onAccent)
                        .padding(4)
                        .background(Circle().fill(Theme.blossom))
                }
                Spacer()
            }

            Text(layered
                 ? "Layer a sound and a track, and balance them."
                 : "Plus plays ambience and music together, with the balance in your hands.")
                .font(.footnote)
                .foregroundStyle(Theme.bark.opacity(0.65))

            slider("Ambience", value: $engine.settings.ambienceVolume, enabled: layered)
            slider("Music", value: $engine.settings.musicVolume, enabled: layered)

            Divider().opacity(0.3)

            Toggle(isOn: Binding(
                get: { engine.settings.radioMode && layered },
                set: { engine.settings.radioMode = layered ? $0 : false }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Radio").font(.subheadline.weight(.semibold))
                    Text("Let the app pick, matched to where you are and the hour.")
                        .font(.caption2)
                        .foregroundStyle(Theme.bark.opacity(0.6))
                }
            }
            .tint(Theme.blossom)
            .disabled(!layered)
            .opacity(layered ? 1 : 0.4)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 18).fill(Theme.surface.opacity(0.7)))
        .contentShape(Rectangle())
        .onTapGesture { if !layered { showPaywall = true } }
    }

    private func slider(_ label: String, value: Binding<Double>, enabled: Bool) -> some View {
        HStack(spacing: 10) {
            Text(label)
                .font(.caption)
                .foregroundStyle(Theme.bark.opacity(0.75))
                .frame(width: 66, alignment: .leading)
            Slider(value: value, in: 0...1)
                .tint(Theme.blossom)
                .disabled(!enabled)
                .opacity(enabled ? 1 : 0.4)
        }
    }

    private func shelf(for collection: MusicCollection) -> some View {
        let unlocked = engine.isUnlocked(collection.gate, hasPlus: store.hasPlus)

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text(collection.title)
                    .font(.headline)
                    .foregroundStyle(Theme.bark.opacity(unlocked ? 1 : 0.55))
                if !unlocked, collection.gate.requiresPlus {
                    Image(systemName: "lock.fill")
                        .font(.caption2)
                        .foregroundStyle(Theme.onAccent)
                        .padding(3)
                        .background(Circle().fill(Theme.blossom))
                }
                Spacer()
            }

            Text(unlocked ? collection.blurb : lockLine(for: collection))
                .font(.footnote)
                .foregroundStyle(Theme.bark.opacity(0.6))

            VStack(spacing: 0) {
                ForEach(collection.tracks) { track in
                    row(for: track, unlocked: unlocked)
                    if track.id != collection.tracks.last?.id {
                        Divider().opacity(0.25)
                    }
                }
            }
            .background(RoundedRectangle(cornerRadius: 16).fill(Theme.surface.opacity(unlocked ? 0.85 : 0.4)))
        }
    }

    private func row(for track: MusicTrack, unlocked: Bool) -> some View {
        let playing = engine.settings.music == track.id

        return Button {
            guard unlocked else {
                if track.gate.requiresPlus { showPaywall = true } else { HapticsDirector.shared.nudge() }
                return
            }
            // Tapping the playing track stops it: silence has to be reachable.
            engine.settings.music = playing ? nil : track.id
            HapticsDirector.shared.detent()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: playing ? "speaker.wave.2.fill" : "music.note")
                    .font(.footnote)
                    .foregroundStyle(playing ? Theme.blossom : Theme.bark.opacity(unlocked ? 0.5 : 0.3))
                    .frame(width: 18)
                Text(track.title)
                    .font(.subheadline.weight(playing ? .semibold : .regular))
                    .foregroundStyle(Theme.bark.opacity(unlocked ? 0.9 : 0.45))
                Spacer()
                Text("\(track.bpm)")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(Theme.bark.opacity(0.4))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            unlocked
                ? "\(track.title), \(track.bpm) beats per minute\(playing ? ", playing" : "")"
                : "\(track.title), locked"
        )
    }

    private func lockLine(for collection: MusicCollection) -> String {
        switch collection.gate {
        case .plus:
            return "Pawmodoro Plus"
        case .arrival(let place):
            let remaining = engine.sessionsRemaining(to: place)
            return remaining > 0
                ? "\(remaining) more session\(remaining == 1 ? "" : "s") to reach \(place.name)"
                : "Reach \(place.name)"
        case .free:
            return collection.blurb
        }
    }
}
