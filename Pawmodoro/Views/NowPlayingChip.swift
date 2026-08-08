import SwiftUI

/// What just started playing, said once and then gone.
///
/// The shape is the buddy's caption and the kept-photo line: footnote
/// `Theme.bark` at 0.75 on a `Theme.cream` capsule at 0.78, fading in and out
/// over `.easeInOut`. That pair is not a taste — it is the pair
/// `tools/check_contrast.py` already measures over every place, weather, theme
/// and appearance, and there is scenery behind this chip like there is behind
/// everything else on that screen.
///
/// Three rules it must keep, all learned the hard way:
///
/// 1. **It takes no taps.** The buddy is underneath, and the whole of the
///    high five was unreachable for a while because a full-screen overlay with
///    a gesture on it swallowed the tap (see `CelebrationView.placedCard`).
///    This one is not a control at all, so the honest answer is
///    `allowsHitTesting(false)` on the whole thing rather than a
///    `contentShape` that takes taps only where it sits.
/// 2. **It never changes the layout.** Placed as an overlay, so appearing and
///    disappearing moves nothing — the same trap the photo control's comment
///    describes, where an extra row of height pushed the play button off a
///    tall phone.
/// 3. **It says a name, and no numbers.** No count, no position in the
///    catalogue, no "1 of 65". A number turns listening into progress.
struct NowPlayingChip: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var now = NowPlaying.shared

    var body: some View {
        ZStack {
            if let track = now.announced {
                capsule(for: track)
                    .transition(.opacity)
            }
        }
        // Driven from the container rather than with `withAnimation` at the
        // announcing end: the announcement comes from an audio callback, which
        // has no business knowing how a view likes to arrive.
        .animation(
            reduceMotion ? nil : .easeInOut(duration: 0.45),
            value: now.announced
        )
        .allowsHitTesting(false)
    }

    private func capsule(for track: MusicTrack) -> some View {
        HStack(spacing: 7) {
            Image(systemName: "music.note")
                .font(.footnote.weight(.semibold))
            label(for: track)
                .font(.footnote)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .foregroundStyle(Theme.bark.opacity(0.75))
        .padding(.horizontal, 14)
        .frame(height: 32)
        // Its own backing, for the same reason the buddy's caption has one:
        // there is a place behind this, and it can be any colour.
        .background(Capsule().fill(Theme.cream.opacity(0.78)))
        // Kept off the edges of a short phone; the scale factor above takes
        // the last few points if a long title meets a narrow screen.
        .frame(maxWidth: 320)
        // The chip is the *fact*, not a control: one static line, no button
        // trait, and nothing that pulls VoiceOver focus to it. It joins the
        // reading order while it is up and leaves when it goes, which is what
        // a spoken caption should do — the alternative, forcing focus, would
        // interrupt somebody mid-sentence to tell them a song changed.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spokenLabel(for: track))
    }

    /// Track first in medium weight, then the tape it came off.
    ///
    /// The two runs differ by *weight* and not by opacity on purpose: the
    /// contrast check measures one text colour on this backing, and a
    /// second, fainter one would be an unmeasured pair sneaking onto the
    /// screen behind a green run.
    private func label(for track: MusicTrack) -> Text {
        let title = Text(track.title).fontWeight(.medium)
        guard let tape = NowPlaying.tape(of: track) else { return title }
        return title + Text("  ·  " + tape)
    }

    private func spokenLabel(for track: MusicTrack) -> String {
        guard let tape = NowPlaying.tape(of: track) else {
            return "Now playing: \(track.title)"
        }
        return "Now playing: \(track.title), from \(tape)"
    }
}

#Preview {
    NowPlayingChip()
        .padding()
        .background(Theme.cream)
}
