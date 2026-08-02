import AVFoundation
import Foundation

/// The music channel.
///
/// This exists as its own engine rather than another `AVAudioPlayer` because
/// AAC cannot be looped gaplessly by a file player: the encoder prepends
/// priming frames and pads the tail, so every repeat ticks. Decoding once into
/// a buffer, trimming it to the exact loop length the generator recorded, and
/// scheduling that buffer with `.loops` is sample-accurate and runs forever
/// with no further work.
///
/// Two player nodes, so changing track can crossfade instead of cutting.
final class MusicPlayer {
    static let shared = MusicPlayer()

    private let engine = AVAudioEngine()
    private let mixer = AVAudioMixerNode()
    private var players: [AVAudioPlayerNode] = [AVAudioPlayerNode(), AVAudioPlayerNode()]
    private var active = 0
    private var buffers: [String: AVAudioPCMBuffer] = [:]

    private(set) var current: MusicTrack?
    private var started = false

    /// 0...1, applied on top of whatever each node is doing.
    var volume: Float = 0.7 {
        didSet { mixer.outputVolume = volume }
    }

    private init() {}

    // MARK: Transport

    func play(_ track: MusicTrack, crossfade: TimeInterval = 1.6) {
        guard track != current else { return }
        guard let buffer = buffer(for: track) else { return }
        guard startEngineIfNeeded() else { return }

        let outgoing = players[active]
        active = (active + 1) % players.count
        let incoming = players[active]

        incoming.stop()
        incoming.volume = 0
        incoming.scheduleBuffer(buffer, at: nil, options: [.loops])
        incoming.play()

        current = track
        ramp(incoming, to: 1, over: crossfade)
        if outgoing.isPlaying {
            ramp(outgoing, to: 0, over: crossfade) { outgoing.stop() }
        }
    }

    func stop(fade: TimeInterval = 0.6) {
        current = nil
        for player in players where player.isPlaying {
            ramp(player, to: 0, over: fade) { player.stop() }
        }
    }

    /// Called when the app is backgrounded: iOS tears the engine down anyway,
    /// and holding it running is the sort of thing that gets an app rejected.
    func suspend() {
        guard started else { return }
        for player in players { player.stop() }
        engine.pause()
    }

    func resumeIfNeeded() {
        guard started, let current else { return }
        // Rebuild from scratch rather than guessing the engine's state.
        let track = current
        self.current = nil
        play(track, crossfade: 0.4)
    }

    // MARK: Plumbing

    private func startEngineIfNeeded() -> Bool {
        guard !started else { return true }
        for player in players {
            engine.attach(player)
        }
        engine.attach(mixer)
        for player in players {
            engine.connect(player, to: mixer, format: nil)
        }
        engine.connect(mixer, to: engine.mainMixerNode, format: nil)
        mixer.outputVolume = volume
        do {
            try engine.start()
            started = true
            return true
        } catch {
            return false
        }
    }

    /// Decodes the track once and trims it to the generator's exact loop
    /// length, dropping the encoder's priming frames.
    private func buffer(for track: MusicTrack) -> AVAudioPCMBuffer? {
        if let cached = buffers[track.id] { return cached }
        guard let url = Self.url(for: track),
              let file = try? AVAudioFile(forReading: url)
        else { return nil }

        let format = file.processingFormat
        let capacity = AVAudioFrameCount(file.length)
        guard capacity > 0,
              let decoded = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity),
              (try? file.read(into: decoded)) != nil
        else { return nil }

        let wanted = AVAudioFrameCount(track.loopFrames)
        guard decoded.frameLength > wanted,
              let trimmed = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: wanted)
        else {
            buffers[track.id] = decoded
            return decoded
        }

        // Priming frames sit at the *start*; any remaining excess is trailing
        // padding. Splitting the difference would land the loop point half a
        // priming block late. In practice CoreAudio already reports the exact
        // length and this path doesn't run — it's here so a decoder that
        // doesn't still loops cleanly.
        let priming = min(AVAudioFrameCount(2112), decoded.frameLength - wanted)
        let channels = Int(format.channelCount)
        if let source = decoded.floatChannelData, let destination = trimmed.floatChannelData {
            for channel in 0..<channels {
                destination[channel].update(
                    from: source[channel] + Int(priming),
                    count: Int(wanted)
                )
            }
        }
        trimmed.frameLength = wanted
        buffers[track.id] = trimmed
        return trimmed
    }

    private static func url(for track: MusicTrack) -> URL? {
        Bundle.main.url(forResource: track.assetName, withExtension: "m4a")
            ?? Bundle.main.url(forResource: track.assetName, withExtension: "m4a", subdirectory: "Music")
    }

    /// Equal-power-ish volume ramp on the node itself. `AVAudioPlayerNode`
    /// has no built-in fade, and a linear jump is audible.
    private func ramp(
        _ player: AVAudioPlayerNode,
        to target: Float,
        over seconds: TimeInterval,
        then finished: (@Sendable () -> Void)? = nil
    ) {
        let steps = max(1, Int(seconds * 30))
        let from = player.volume
        Task { @MainActor in
            for step in 1...steps {
                let progress = Float(step) / Float(steps)
                player.volume = from + (target - from) * progress
                try? await Task.sleep(nanoseconds: UInt64(seconds / Double(steps) * 1_000_000_000))
            }
            player.volume = target
            finished?()
        }
    }
}
