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

    private var ambiencePlayer: AVAudioPlayer?
    private var chimePlayer: AVAudioPlayer?
    private var currentAmbience: Ambience = .off
    private var sessionConfigured = false

    private init() {}

    func setAmbience(_ ambience: Ambience) {
        guard ambience != currentAmbience else { return }
        currentAmbience = ambience

        guard let fileName = ambience.fileName else {
            ambiencePlayer?.stop()
            ambiencePlayer = nil
            return
        }

        configureSessionIfNeeded()
        ambiencePlayer?.stop()
        ambiencePlayer = makePlayer(named: fileName)
        ambiencePlayer?.numberOfLoops = -1
        ambiencePlayer?.volume = 0.55
        ambiencePlayer?.play()
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
        guard let url = Bundle.main.url(forResource: fileName, withExtension: "wav"),
              let player = try? AVAudioPlayer(contentsOf: url)
        else {
            return nil
        }
        player.prepareToPlay()
        return player
    }

    private func configureSessionIfNeeded() {
        guard !sessionConfigured else { return }
        sessionConfigured = true
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, mode: .default)
        try? session.setActive(true)
    }
}
