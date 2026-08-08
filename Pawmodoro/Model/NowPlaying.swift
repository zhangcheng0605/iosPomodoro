import Foundation

/// The one thing the screen needs to know about the music channel: which
/// track has *just started*.
///
/// `MusicPlayer` is an audio graph and has no business being observable — it
/// runs off a rotation task, a configuration-change notification and a
/// crossfade, none of which are view state. So it announces here instead, and
/// this is the only music state a view ever watches.
///
/// Why it exists at all: radio mode walks the whole catalogue unattended, so
/// tracks change with nothing on screen ever saying what they are. Sixty-five
/// tracks were written and a listener could not learn a single name. The
/// announcement is deliberately *not* a now-playing readout — it holds for a
/// few seconds and then clears itself, because a permanent one would be a
/// media player, and this app is not that.
///
/// Nothing here is persisted: a name that was said is not a fact about the
/// world, and `StorageKeys` stays out of it.
@Observable
final class NowPlaying {
    static let shared = NowPlaying()

    /// The track worth saying out loud, or nil once it has had its moment.
    private(set) var announced: MusicTrack?

    /// How long a name stays up.
    ///
    /// Six seconds, which is what `BuddyView.say(_:for:)` gives a remark. It
    /// is the same kind of sentence in the same voice on the same screen, so
    /// it holds for the same time — matching the buddy's caption is the whole
    /// brief for the feel of this thing.
    static let dwell: TimeInterval = 6

    /// The last track handed to `announce`, whether or not it was shown.
    ///
    /// The player re-schedules the track it is *already* playing more often
    /// than you would think: `resumeIfNeeded` after the app comes back from
    /// the background, and the audio-engine configuration observer when
    /// headphones are unplugged, both clear `current` and play it again. That
    /// is not news, and a chip that appeared every time somebody picked their
    /// phone up would be the nagging this app doesn't do.
    private var last: String?

    private var dismissal: Task<Void, Never>?

    private init() {}

    /// Called by `MusicPlayer.play` once a genuinely new track is scheduled.
    ///
    /// Main-thread by construction: every caller of `play` is either on the
    /// main actor already (the engine, the radio rotation task) or a
    /// notification delivered to `.main`.
    func announce(_ track: MusicTrack) {
        guard track.id != last else { return }
        last = track.id
        announced = track
        dismissal?.cancel()
        dismissal = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(Self.dwell * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.announced = nil
        }
    }

    /// The music stopped — the phase ended, or the timer was reset.
    ///
    /// `last` is cleared too, so the next session naming its opening track
    /// counts as news again. Only a repeat *within* one stretch of playback is
    /// the thing worth swallowing.
    func silence() {
        dismissal?.cancel()
        dismissal = nil
        announced = nil
        last = nil
    }

    /// The tape a track came off, by name. `MusicCatalog` is generated and
    /// carries no such lookup, so it lives here rather than in the file that
    /// gets rewritten every time the generator runs.
    static func tape(of track: MusicTrack) -> String? {
        MusicCatalog.collections.first { $0.id == track.collection }?.title
    }
}
