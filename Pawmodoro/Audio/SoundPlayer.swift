import AVFoundation
import Foundation

/// Plays the looping ambience and the phase-end chime.
///
/// The audio session uses `.ambient`, which mixes with whatever else is playing
/// and honours the ringer switch. That deliberately avoids the background-audio
/// capability, which App Review scrutinises and this app does not need: when the
/// app is suspended the loop stops, and the local notification takes over.
final class SoundPlayer {
    static let shared = SoundPlayer()

    private var chimePlayer: AVAudioPlayer?
    private var purrPlayer: AVAudioPlayer?
    private var heardPlayer: AVAudioPlayer?
    /// Held for the same reason `heardPlayer` is: an `AVAudioPlayer` that goes
    /// out of scope stops playing, and a three-second bell would be a click.
    private var bellPlayer: AVAudioPlayer?
    private var purrStopTask: Task<Void, Never>?
    private var currentAmbience: Ambience = .off
    private var sessionConfigured = false

    /// Balance against the music channel. Applied live, so moving the slider
    /// is audible immediately rather than at the next phase.
    var ambienceVolume: Float = 0.8 {
        didSet { AmbienceLoop.shared.volume = 0.55 * ambienceVolume }
    }

    private init() {}

    /// A short purr when the buddy is petted.
    ///
    /// Its own player, so it can overlap the ambience loop without stopping it,
    /// and quiet enough to sit under whatever else is playing. Fades out by
    /// stopping on a timer — the loop file has no natural ending.
    func playPurr() {
        configureSessionIfNeeded()
        if purrPlayer == nil {
            purrPlayer = makePlayer(named: "purr")
            purrPlayer?.numberOfLoops = -1
            purrPlayer?.volume = 0.3
        }
        guard let player = purrPlayer else { return }
        if !player.isPlaying {
            player.currentTime = 0
            player.play()
        }
        // Each pet extends the purr rather than restarting it.
        purrStopTask?.cancel()
        purrStopTask = Task { [weak player] in
            try? await Task.sleep(nanoseconds: 1_400_000_000)
            guard !Task.isCancelled else { return }
            player?.stop()
        }
    }

    func setAmbience(_ ambience: Ambience, place: Place = .meadow) {
        guard ambience != currentAmbience else { return }
        currentAmbience = ambience
        configureSessionIfNeeded()
        AmbienceLoop.shared.volume = Float(0.55 * ambienceVolume)
        AmbienceLoop.shared.place = place
        AmbienceLoop.shared.play(ambience)
    }

    /// One of the things you can only hear, played once, quietly, under
    /// whatever else is going. Its own player so it never interrupts the
    /// ambience or the music — the point is that it arrives *inside* them.
    func playHeard(_ sound: Heard) {
        configureSessionIfNeeded()
        guard let player = makePlayer(named: sound.fileName) else { return }
        player.volume = 0.5
        heardPlayer = player
        player.play()
    }

    /// The top of the hour, in the voice of wherever you are sitting.
    ///
    /// Exactly the same shape as `playHeard`: one pre-rendered file, one
    /// `AVAudioPlayer` of its own, played once over whatever else is going.
    /// The hour's grade is *in the file* — there is no filtering, ducking or
    /// layering here, and there must not be, because that is the class of
    /// change that once made the whole app unlaunchable on a real device.
    ///
    /// Quieter than the chime and a shade under a found sound. The chime is
    /// the app telling you something; this is only the world going on.
    func playBell(_ voice: BellVoice, part: DayPart) {
        configureSessionIfNeeded()
        guard let player = makePlayer(named: voice.fileName(for: part)) else { return }
        player.volume = 0.45
        bellPlayer = player
        player.play()
    }

    func playChime() {
        configureSessionIfNeeded()
        if chimePlayer == nil {
            chimePlayer = makePlayer(named: "chime")
            chimePlayer?.volume = 0.8
        }
        chimePlayer?.currentTime = 0
        chimePlayer?.play()
    }

    private func makePlayer(named fileName: String) -> AVAudioPlayer? {
        // Synchronized groups normally copy resources to the bundle root, but fall
        // back to the subdirectory in case Xcode preserves the folder structure.
        let url = Bundle.main.url(forResource: fileName, withExtension: "wav")
            ?? Bundle.main.url(forResource: fileName, withExtension: "wav", subdirectory: "Resources")
        guard let url, let player = try? AVAudioPlayer(contentsOf: url) else { return nil }
        player.prepareToPlay()
        return player
    }

    private func configureSessionIfNeeded() {
        guard !sessionConfigured else { return }
        sessionConfigured = true
        Platform.activateAmbientAudioSession()
    }
}
