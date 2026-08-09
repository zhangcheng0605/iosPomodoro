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
                    restingNote
                    ambienceSection
                    mixerSection
                    ForEach(MusicCatalog.shelf.filter(isShown)) { collection in
                        shelf(for: collection)
                    }
                }
                .padding()
            }
            .sheetSize()
            .background(Theme.cream.ignoresSafeArea())
            .navigationTitle("Sound Studio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // `.confirmationAction`, not `.topBarTrailing`. This was the
                // last screen in the app still asking a sheet's toolbar for a
                // primary control, and on macOS that renders *nothing*: the
                // Sound Studio had a title, a scroll area, and no button of
                // any kind. Escape closed it, and nothing on screen said so.
                // The placement table in `Platform.swift` has the measurement.
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showPaywall) { PaywallView() }
        }
    }

    // MARK: Sections

    /// Why the room is quiet.
    ///
    /// Both channels follow the timer — `TimerEngine.refreshAmbience()` and
    /// `refreshMusic()` each return early unless `runState == .running` — so
    /// choosing a sound or a track while the timer is resting is *designed* to
    /// play nothing. That rule was nowhere on this screen, and the screen
    /// actively contradicted it: the chosen row lit its speaker as though the
    /// track were sounding. Somebody who picks a track, hears silence and has
    /// just installed the app on a second machine concludes, reasonably, that
    /// the second machine is broken. The Mac was the first place that happened
    /// because it is where a new install is most likely to be tried before a
    /// first session. Nothing about it is platform-specific.
    ///
    /// Shown only while the timer is resting: while it runs the answer is
    /// audible, and a notice that restates what you can already hear is just
    /// something else to read.
    @ViewBuilder
    private var restingNote: some View {
        if engine.runState != .running {
            Text("The sound and the track start with the session, and rest when it rests.")
                .font(.footnote)
                .foregroundStyle(Theme.bark.opacity(0.65))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var ambienceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Ambience")
                .font(.headline)
                .foregroundStyle(Theme.bark)
            // Ambience is not in the cart, so every lock here is a paywall lock.
            AmbiencePicker { _ in showPaywall = true }
        }
    }

    @ViewBuilder
    private var mixerSection: some View {
        @Bindable var engine = engine
        let hasMixer = store.hasPlus || LaunchOptions.unlockMusic

        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Mixer")
                    .font(.headline)
                    .foregroundStyle(Theme.bark)
                if !hasMixer {
                    Image(systemName: "lock.fill")
                        .font(.caption2)
                        .foregroundStyle(Theme.onAccent)
                        .padding(4)
                        .background(Circle().fill(Theme.blossom))
                }
                Spacer()
            }

            // A sound and a track play together either way. What is behind
            // the padlock is the balance between them and the radio, and the
            // locked line has to say only that — promising a free user
            // something they can already hear is the worst kind of paywall.
            Text(hasMixer
                 ? "Balance the sound against the track, or let radio pick."
                 : "A sound and a track already play together. Plus puts the balance in your hands, and adds radio.")
                .font(.footnote)
                .foregroundStyle(Theme.bark.opacity(0.65))

            slider("Ambience", value: $engine.settings.ambienceVolume, enabled: hasMixer)
            slider("Music", value: $engine.settings.musicVolume, enabled: hasMixer)

            Divider().opacity(0.3)

            Toggle(isOn: Binding(
                get: { engine.settings.radioMode && hasMixer },
                set: { engine.settings.radioMode = hasMixer ? $0 : false }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Radio").font(.subheadline.weight(.semibold))
                    Text("Let the app pick, matched to where you are and the hour.")
                        .font(.caption2)
                        .foregroundStyle(Theme.bark.opacity(0.6))
                }
            }
            .tint(Theme.blossom)
            .disabled(!hasMixer)
            .opacity(hasMixer ? 1 : 0.4)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 18).fill(Theme.surface.opacity(0.7)))
        .contentShape(Rectangle())
        .onTapGesture { if !hasMixer { showPaywall = true } }
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

    /// One track on a shelf.
    ///
    /// **Chosen and sounding are two different things**, and this row used to
    /// draw only one of them: the selected track showed a speaker with waves
    /// coming out of it whether or not a single sample was flowing. With the
    /// timer resting that is the app stating, in the one place a person looks
    /// to check, that a track is playing when the engine has not been asked to
    /// play anything. A waveless speaker says *chosen*; the waves are reserved
    /// for sound actually leaving the app.
    private func row(for track: MusicTrack, unlocked: Bool) -> some View {
        let chosen = engine.settings.music == track.id
        let sounding = chosen && engine.runState == .running

        return Button {
            guard unlocked else {
                if track.gate.requiresPlus { showPaywall = true } else { HapticsDirector.shared.nudge() }
                return
            }
            // Tapping the chosen track clears it: silence has to be reachable.
            engine.settings.music = chosen ? nil : track.id
            HapticsDirector.shared.detent()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: sounding ? "speaker.wave.2.fill"
                                           : (chosen ? "speaker.fill" : "music.note"))
                    .font(.footnote)
                    .foregroundStyle(chosen ? Theme.blossom : Theme.bark.opacity(unlocked ? 0.5 : 0.3))
                    .frame(width: 18)
                Text(track.title)
                    .font(.subheadline.weight(chosen ? .semibold : .regular))
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
                ? "\(track.title), \(track.bpm) beats per minute\(chosenSuffix(chosen: chosen, sounding: sounding))"
                : "\(track.title), locked"
        )
    }

    /// VoiceOver hears the same distinction the icon draws — and the resting
    /// case says what will happen, because a blind user cannot check by ear
    /// whether the silence is a fault.
    private func chosenSuffix(chosen: Bool, sounding: Bool) -> String {
        if sounding { return ", playing" }
        if chosen { return ", chosen, starts with the session" }
        return ""
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
        // A found tape says what kind of hour finds it and never how many are
        // left, unlike the line above. That asymmetry is deliberate: an
        // arrival is a distance and a number is the honest way to say one,
        // while "two more rainy sessions" would turn sitting through the rain
        // into an errand — and the errand would be to wait for bad weather.
        case .found(let finding):
            return finding.findingLine
        case .free:
            return collection.blurb
        }
    }

    /// Whether the shelf shows a collection at all.
    ///
    /// Locked mixtapes are shown with their lock line, always — except Soot's,
    /// for the reason `MusicFinding.isHidden` gives.
    private func isShown(_ collection: MusicCollection) -> Bool {
        guard case .found(let finding) = collection.gate, finding.isHidden
        else { return true }
        return engine.isUnlocked(collection.gate, hasPlus: store.hasPlus)
    }
}
