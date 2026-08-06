import AVFoundation
import Foundation

/// The ambience channel, on the same path the music takes.
///
/// The loops became AAC when the circadian grades made four copies of each
/// one: eighteen loops as WAV is twelve megabytes and seventy-two would have
/// been forty-eight, which no phone should carry for background noise. AAC
/// makes the same seventy-two about nine.
///
/// That change costs a player, though. `AVAudioPlayer.numberOfLoops = -1` is
/// perfect on a WAV and useless on an AAC: the encoder prepends priming
/// frames and pads the tail, so every repeat ticks. The fix is the one the
/// music already uses — decode once, trim to the frame count the generator
/// recorded, and schedule that buffer with `.loops`.
///
/// Deliberately a copy of `MusicPlayer`'s shape rather than a shared
/// abstraction. The two channels are independent by design: either can be
/// silent while the other plays, and folding them into one class would make
/// a change to the music a change to the rain. What *is* shared is the hard
/// lesson — the format rule below is the crash that made fifty tracks
/// unplayable, and it is written out again here because it will be
/// rediscovered here otherwise.
final class AmbienceLoop {
    static let shared = AmbienceLoop()

    private let engine = AVAudioEngine()
    private let mixer = AVAudioMixerNode()
    private let player = AVAudioPlayerNode()
    private var buffers: [String: AVAudioPCMBuffer] = [:]
    private var current: Ambience = .off
    private var attached = false
    private var connectedFormat: AVAudioFormat?
    private var configObserver: NSObjectProtocol?

    var volume: Float = 0.45 {
        didSet { mixer.outputVolume = volume }
    }

    private init() {}

    func play(_ ambience: Ambience) {
        guard ambience != current || !engine.isRunning else { return }
        current = ambience

        guard ambience != .off, let buffer = buffer(for: ambience) else {
            player.stop()
            return
        }
        guard start(format: buffer.format) else { return }
        // Belt and braces, as on the music side: a format mismatch here is an
        // Objective-C exception Swift cannot catch, and the process dies.
        guard let connectedFormat, connectedFormat.isEqual(buffer.format) else { return }

        player.stop()
        player.scheduleBuffer(buffer, at: nil, options: [.loops])
        player.play()
    }

    func stop() {
        current = .off
        player.stop()
    }

    /// Backgrounding: iOS tears the engine down anyway, and an ambience that
    /// keeps a graph alive in the background is the kind of thing that gets
    /// an app rejected.
    func suspend() {
        player.stop()
        if engine.isRunning { engine.pause() }
    }

    func resumeIfNeeded() {
        let wanted = current
        guard wanted != .off else { return }
        current = .off
        play(wanted)
    }

    // MARK: Plumbing

    /// The player→mixer connection must carry the **buffer's** format, never
    /// nil. Nil means the hardware's, which on a phone is stereo 48 kHz while
    /// every loop here is mono 22.05 kHz; `scheduleBuffer` then throws and
    /// takes the app with it. The Simulator negotiates a compatible format
    /// and shows none of this, which is exactly how it shipped broken once.
    private func start(format: AVAudioFormat) -> Bool {
        if !attached {
            engine.attach(player)
            engine.attach(mixer)
            attached = true
            observeConfigurationChanges()
        }
        if connectedFormat == nil || !connectedFormat!.isEqual(format) {
            engine.connect(mixer, to: engine.mainMixerNode, format: nil)
            player.stop()
            engine.disconnectNodeOutput(player)
            engine.connect(player, to: mixer, format: format)
            connectedFormat = format
        }
        mixer.outputVolume = volume
        if !engine.isRunning {
            do { try engine.start() } catch { return false }
        }
        return engine.isRunning
    }

    /// Unplugging headphones rebuilds the graph underneath us and leaves the
    /// cached format describing something that no longer exists.
    private func observeConfigurationChanges() {
        guard configObserver == nil else { return }
        configObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            self.connectedFormat = nil
            let wanted = self.current
            guard wanted != .off else { return }
            self.current = .off
            self.play(wanted)
        }
    }

    /// Decoded once, then trimmed to the generator's exact frame count.
    ///
    /// Only one loop is ever held: unlike the music, ambience does not
    /// crossfade between two of them, so there is nothing to keep a second
    /// decoded buffer for. Eighteen of these resident would be most of a
    /// hundred megabytes.
    private func buffer(for ambience: Ambience) -> AVAudioPCMBuffer? {
        if let cached = buffers[ambience.rawValue] { return cached }
        guard let name = ambience.fileName,
              let url = Bundle.main.url(forResource: name, withExtension: "m4a")
                ?? Bundle.main.url(forResource: name, withExtension: "m4a",
                                   subdirectory: "Resources"),
              let file = try? AVAudioFile(forReading: url)
        else { return nil }

        let format = file.processingFormat
        let capacity = AVAudioFrameCount(file.length)
        guard capacity > 0,
              let decoded = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity),
              (try? file.read(into: decoded)) != nil
        else { return nil }

        var result = decoded
        if let frames = ambience.loopFrames {
            let wanted = AVAudioFrameCount(frames)
            if decoded.frameLength > wanted,
               let trimmed = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: wanted) {
                let priming = min(AVAudioFrameCount(2112), decoded.frameLength - wanted)
                let channels = Int(format.channelCount)
                if let source = decoded.floatChannelData,
                   let destination = trimmed.floatChannelData {
                    for channel in 0..<channels {
                        destination[channel].update(
                            from: source[channel] + Int(priming), count: Int(wanted))
                    }
                }
                trimmed.frameLength = wanted
                result = trimmed
            }
        }
        buffers = [ambience.rawValue: result]
        return result
    }
}
